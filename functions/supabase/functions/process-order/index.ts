// supabase/functions/process-order/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'

// Define TypeScript interfaces for type safety
interface OrderItem {
  menu_item_id: string
  quantity: number
  special_instructions?: string
  unit_price?: number
}

interface OrderRequest {
  establishment_id: string
  table_id: string
  items: OrderItem[]
  total_amount: number
  special_instructions?: string
  payment_method?: 'cash' | 'card' | 'mobile_money' | 'dine_coins'
  dine_coins_used?: number
  group_session_id?: string
}

interface MenuItemInfo {
  id: string
  price: number
  is_available: boolean
  name: string
}

serve(async (req) => {
  // Handle CORS preflight requests [citation:3]
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // 1. Get the authorization header
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      throw new Error('Missing Authorization header')
    }

    // 2. Initialize the Supabase client with the auth token
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      {
        global: { headers: { Authorization: authHeader } },
        auth: {
          persistSession: false // Edge Functions don't need session persistence
        }
      }
    )

    // 3. Get the authenticated user from the JWT [citation:1]
    const { data: { user }, error: authError } = await supabaseClient.auth.getUser()
    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized - Invalid or expired token' }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 401,
        }
      )
    }

    // 4. Get and validate the request body
    let orderData: OrderRequest
    try {
      orderData = await req.json()
    } catch (parseError) {
      return new Response(
        JSON.stringify({ error: 'Invalid JSON payload' }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 400,
        }
      )
    }

    // Validate required fields
    if (!orderData.establishment_id || !orderData.table_id || !orderData.items || orderData.items.length === 0) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields: establishment_id, table_id, and items are required' }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 400,
        }
      )
    }

    // 5. Validate menu items and check availability
    const menuItemIds = orderData.items.map(item => item.menu_item_id)
    const { data: menuItems, error: menuError } = await supabaseClient
      .from('menu_items')
      .select('id, price, is_available, name')
      .in('id', menuItemIds)

    if (menuError) {
      throw new Error(`Failed to fetch menu items: ${menuError.message}`)
    }

    const menuItemMap = new Map<string, MenuItemInfo>()
    menuItems.forEach(item => {
      menuItemMap.set(item.id, item as MenuItemInfo)
    })

    // Check all items exist and are available
    const validationErrors: string[] = []
    orderData.items.forEach((item, index) => {
      const menuItem = menuItemMap.get(item.menu_item_id)
      if (!menuItem) {
        validationErrors.push(`Item at index ${index}: Menu item not found`)
      } else if (!menuItem.is_available) {
        validationErrors.push(`Item at index ${index}: "${menuItem.name}" is not available`)
      } else if (item.quantity <= 0) {
        validationErrors.push(`Item at index ${index}: Quantity must be greater than 0`)
      }
    })

    if (validationErrors.length > 0) {
      return new Response(
        JSON.stringify({
          error: 'Validation failed',
          details: validationErrors
        }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 400,
        }
      )
    }

    // 6. Calculate total and validate against provided total
    const calculatedTotal = orderData.items.reduce((sum, item) => {
      const menuItem = menuItemMap.get(item.menu_item_id)!
      return sum + (menuItem.price * item.quantity)
    }, 0)

    if (Math.abs(calculatedTotal - orderData.total_amount) > 0.01) {
      return new Response(
        JSON.stringify({
          error: 'Total amount mismatch',
          calculated: calculatedTotal,
          provided: orderData.total_amount
        }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 400,
        }
      )
    }

    // 7. Check DineCoins balance if using DineCoins
    if (orderData.payment_method === 'dine_coins') {
      const { data: dineCoinsData } = await supabaseClient
        .from('dinecoins_ledger')
        .select('amount, transaction_type')
        .eq('user_id', user.id)

      const balance = (dineCoinsData || []).reduce((total, record) => {
        return total + (record.transaction_type === 'credit'
          ? (record.amount as number)
          : -(record.amount as number))
      }, 0)

      const dineCoinsUsed = orderData.dine_coins_used || 0
      if (dineCoinsUsed > balance) {
        return new Response(
          JSON.stringify({
            error: 'Insufficient DineCoins balance',
            balance,
            requested: dineCoinsUsed
          }),
          {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 400,
          }
        )
      }
    }

    // 8. Create order and order items in a transaction
    const { data: order, error: orderError } = await supabaseClient
      .from('orders')
      .insert({
        establishment_id: orderData.establishment_id,
        table_id: orderData.table_id,
        customer_id: user.id,
        status: 'pending',
        total_amount: orderData.total_amount,
        special_instructions: orderData.special_instructions,
        group_session_id: orderData.group_session_id
      })
      .select()
      .single()

    if (orderError) {
      throw new Error(`Failed to create order: ${orderError.message}`)
    }

    // Prepare order items with calculated prices
    const orderItems = orderData.items.map(item => {
      const menuItem = menuItemMap.get(item.menu_item_id)!
      return {
        order_id: order.id,
        menu_item_id: item.menu_item_id,
        quantity: item.quantity,
        unit_price: menuItem.price,
        line_total: menuItem.price * item.quantity,
        special_instructions: item.special_instructions
      }
    })

    const { error: itemsError } = await supabaseClient
      .from('order_items')
      .insert(orderItems)

    if (itemsError) {
      // Attempt to clean up the order if items failed
      await supabaseClient.from('orders').delete().eq('id', order.id)
      throw new Error(`Failed to create order items: ${itemsError.message}`)
    }

    // 9. Create payment record
    const paymentStatus = orderData.payment_method === 'dine_coins' &&
                         (orderData.dine_coins_used || 0) >= orderData.total_amount
                         ? 'completed'
                         : 'pending'

    const { data: payment, error: paymentError } = await supabaseClient
      .from('payments')
      .insert({
        order_id: order.id,
        amount: orderData.total_amount - (orderData.dine_coins_used || 0),
        payment_method: orderData.payment_method || 'cash',
        dine_coins_used: orderData.dine_coins_used || 0,
        status: paymentStatus
      })
      .select()
      .single()

    if (paymentError) {
      // Clean up order and items if payment fails
      await supabaseClient.from('order_items').delete().eq('order_id', order.id)
      await supabaseClient.from('orders').delete().eq('id', order.id)
      throw new Error(`Failed to create payment: ${paymentError.message}`)
    }

    // 10. Create DineCoins ledger entry if DineCoins were used
    if (orderData.payment_method === 'dine_coins' && orderData.dine_coins_used && orderData.dine_coins_used > 0) {
      const { error: ledgerError } = await supabaseClient
        .from('dinecoins_ledger')
        .insert({
          user_id: user.id,
          establishment_id: orderData.establishment_id,
          amount: orderData.dine_coins_used,
          transaction_type: 'debit',
          description: `Payment for order ${order.id.substring(0, 8)}`,
          supervisor_id: null // Set to null for automated transactions
        })

      if (ledgerError) {
        console.error('Failed to create DineCoins ledger entry:', ledgerError)
        // Don't roll back the order - just log the error
      }
    }

    // 11. Return successful response
    return new Response(
      JSON.stringify({
        message: 'Order processed successfully!',
        order: {
          id: order.id,
          order_number: order.id.substring(0, 8).toUpperCase(),
          status: order.status,
          total: order.total_amount,
          created_at: order.created_at
        },
        payment: {
          id: payment.id,
          status: payment.status,
          method: payment.payment_method,
          dine_coins_used: payment.dine_coins_used
        },
        items: orderItems.length
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 201,
      },
    )

  } catch (error) {
    // Handle any errors with proper status codes [citation:4]
    console.error('Order processing error:', error)

    const statusCode = error.message.includes('Unauthorized') ? 401 :
                      error.message.includes('Validation') ? 400 :
                      error.message.includes('not found') ? 404 : 500

    return new Response(
      JSON.stringify({
        error: 'Order processing failed',
        message: error.message,
        timestamp: new Date().toISOString()
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: statusCode,
      },
    )
  }
})
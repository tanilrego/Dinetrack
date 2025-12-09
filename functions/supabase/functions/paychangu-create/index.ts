// supabase/functions/paychangu-create/index.ts
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// Define CORS headers
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS', // Explicitly add allowed methods
}

Deno.serve(async (req) => {
  // 1. Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { order_id, tx_ref, payer_customer_id, amount } = await req.json()

    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Validate the payment and get customer details
    const { data: validation, error: validationError } = await supabaseClient
      .rpc('validate_payment_creation', {
        p_order_id: order_id,
        p_payer_customer_id: payer_customer_id
      })

    if (validationError || !validation?.valid) {
      throw new Error(validation?.error || 'Validation failed')
    }

    // Call PayChangu API to create payment
    const paychanguResponse = await fetch('https://api.paychangu.com/v1/payments', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${Deno.env.get('PAYCHANGU_API_KEY')}`,
        'Content-Type': 'application/json',
        'Idempotency-Key': tx_ref, // Use tx_ref as idempotency key
      },
      body: JSON.stringify({
        amount: Math.round(amount * 100), // Convert to cents
        currency: 'MWK',
        tx_ref: tx_ref,
        customer: {
          id: payer_customer_id,
          email: validation.customer.email,
          phone: validation.customer.phone,
          first_name: validation.customer.first_name,
          last_name: validation.customer.last_name,
        },
        metadata: {
          order_id: order_id,
          order_number: validation.order.order_number,
          establishment_id: validation.establishment.id,
        },
        return_url: 'https://dinetrack-3hhc.onrender.com/payment-complete',
        callback_url: 'https://xsflgrmqvnggtdggacrd.supabase.co/functions/v1/paychangu-webhook',
      }),
    })

    if (!paychanguResponse.ok) {
      const errorText = await paychanguResponse.text()
      console.error('PayChangu API error:', errorText)
      throw new Error(`PayChangu API error: ${paychanguResponse.status}`)
    }

    const paymentData = await paychanguResponse.json()

    // Create payment record in database
    const { data: payment, error: paymentError } = await supabaseClient
      .from('payments')
      .insert({
        order_id: order_id,
        amount: amount,
        payment_method: 'paychangu',
        status: 'pending',
        idempotency_key: tx_ref,
        provider_payment_id: paymentData.id,
        checkout_url: paymentData.checkout_url || paymentData.payment_url,
        payer_customer_id: payer_customer_id,
        metadata: paymentData,
      })
      .select()
      .single()

    if (paymentError) {
      throw paymentError
    }

    // Parse customer name (assuming full_name format)
    const fullName = validation.customer.full_name || 'Customer Name'
    const nameParts = fullName.split(' ')
    const firstName = nameParts[0] || 'Customer'
    const lastName = nameParts.length > 1 ? nameParts.slice(1).join(' ') : 'Name'

    // Return data needed by Flutter app
    return new Response(
      JSON.stringify({
        success: true,
        secret_key: Deno.env.get('PAYCHANGU_API_KEY'),
        checkout_url: paymentData.checkout_url || paymentData.payment_url,
        first_name: firstName,
        last_name: lastName,
        email: validation.customer.email,
        payment_id: payment.id,
        tx_ref: tx_ref,
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    )

  } catch (error) {
    console.error('Error in paychangu-create:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      }
    )
  }
})
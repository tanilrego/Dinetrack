import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// Define CORS headers
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const payload = await req.json().catch(() => ({}))
    const { order_id, tx_ref, payer_customer_id } = payload
    let { amount } = payload

    if (!order_id || !tx_ref || !payer_customer_id || amount == null) {
      return new Response(JSON.stringify({ error: 'Missing required fields' }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    // normalize amount to number
    amount = Number(amount)
    if (Number.isNaN(amount) || amount <= 0) {
      return new Response(JSON.stringify({ error: 'Invalid amount' }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    const supabaseClient = createClient(Deno.env.get('SUPABASE_URL') ?? '', Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '')

    // Validate the payment and get customer details
    const { data: validation, error: validationError } = await supabaseClient
      .rpc('validate_payment_creation', { p_order_id: order_id, p_payer_customer_id: payer_customer_id })

    if (validationError) {
      console.error('Validation RPC error', validationError)
      throw validationError
    }

    if (!validation || !validation.valid) {
      const msg = validation?.error || 'Validation failed'
      console.error(msg)
      return new Response(JSON.stringify({ error: msg }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    // Call PayChangu API to create payment
    const paychanguResp = await fetch('https://api.paychangu.com/v1/payments', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${Deno.env.get('PAYCHANGU_API_KEY')}`,
        'Content-Type': 'application/json',
        'Idempotency-Key': tx_ref,
      },
      body: JSON.stringify({
        amount: Math.round(amount * 100),
        currency: 'MWK',
        tx_ref,
        customer: {
          id: payer_customer_id,
          email: validation.customer.email,
          phone: validation.customer.phone,
          first_name: validation.customer.first_name,
          last_name: validation.customer.last_name,
        },
        metadata: {
          order_id,
          order_number: validation.order?.order_number,
          establishment_id: validation.establishment?.id,
        },
        return_url: 'https://dinetrack-3hhc.onrender.com/payment-complete',
        callback_url: `${Deno.env.get('SUPABASE_URL')}/functions/v1/paychangu-webhook`,
      }),
    })

    if (!paychanguResp.ok) {
      const text = await paychanguResp.text()
      console.error('PayChangu API error:', paychanguResp.status, text)
      return new Response(JSON.stringify({ error: 'PayChangu API error', details: text }), { status: 502, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    const paymentData = await paychanguResp.json()

    // Upsert payment by idempotency_key (tx_ref)
    const insertObj = {
      order_id,
      amount,
      payment_method: 'paychangu',
      status: 'pending',
      idempotency_key: tx_ref,
      provider_payment_id: paymentData.id,
      checkout_url: paymentData.checkout_url || paymentData.payment_url || paymentData.url,
      payer_customer_id,
      metadata: paymentData,
    }

    const { data: payment, error: paymentError } = await supabaseClient
      .from('payments')
      .upsert(insertObj, { onConflict: 'idempotency_key', ignoreDuplicates: false })
      .select()
      .single()

    if (paymentError) {
      console.error('Payments upsert error', paymentError)
      return new Response(JSON.stringify({ error: 'Database error', details: paymentError.message }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    const fullName = validation.customer.full_name || `${validation.customer.first_name || ''} ${validation.customer.last_name || ''}`.trim() || 'Customer Name'
    const nameParts = fullName.split(' ')
    const firstName = nameParts[0] || 'Customer'
    const lastName = nameParts.length > 1 ? nameParts.slice(1).join(' ') : 'Name'

    return new Response(JSON.stringify({ success: true, checkout_url: insertObj.checkout_url, first_name: firstName, last_name: lastName, email: validation.customer.email, payment_id: payment.id, tx_ref }), { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })

  } catch (err) {
    console.error('Error in paychangu-create:', err)
    return new Response(JSON.stringify({ error: String(err) }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
  }
});
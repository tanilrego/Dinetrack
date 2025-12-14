import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? ''
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
const PAYCHANGU_WEBHOOK_SECRET = Deno.env.get('PAYCHANGU_WEBHOOK_SECRET') ?? ''

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-paychangu-signature',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

function verifySignature(payload: string, signature: string | null): boolean {
  if (!PAYCHANGU_WEBHOOK_SECRET) {
    console.warn('No webhook secret configured; skipping signature verification')
    return true
  }
  if (!signature) {
    console.warn('No signature header present')
    return false
  }
  try {
    // HMAC-SHA256 verification
    const encoder = new TextEncoder()
    const keyData = encoder.encode(PAYCHANGU_WEBHOOK_SECRET)
    const algo = { name: 'HMAC', hash: 'SHA-256' }
    // import key
    // @ts-ignore - Web Crypto in Deno
    const cryptoKey = await crypto.subtle.importKey('raw', keyData, algo, false, ['verify'])
    const signatureBuf = Uint8Array.from(Buffer.from(signature, 'hex'))
    const payloadBuf = encoder.encode(payload)
    // @ts-ignore
    const isValid = await crypto.subtle.verify(algo, cryptoKey, signatureBuf, payloadBuf)
    return Boolean(isValid)
  } catch (e) {
    console.error('Signature verification error', e)
    return false
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return new Response('Method not allowed', { status: 405 })

  let payloadText = ''
  try {
    payloadText = await req.text()
    const signature = req.headers.get('x-paychangu-signature')

    if (!verifySignature || !(await verifySignature(payloadText, signature))) {
      // If verification fails, log and continue returning 401
      console.warn('Webhook signature verification failed')
      return new Response(JSON.stringify({ success: false, error: 'Invalid signature' }), { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    const data = JSON.parse(payloadText)
    console.log('Webhook received:', JSON.stringify(data))

    const providerPaymentId = data.id ?? data.transaction_id ?? data.provider_payment_id
    const txRef = data.tx_ref ?? data.metadata?.tx_ref ?? data.metadata?.idempotency_key
    const webhookStatusRaw = data.status ?? data.state

    if (!providerPaymentId && !txRef) {
      console.error('No providerPaymentId or tx_ref in webhook')
      await supabase.from('payment_webhook_logs').insert({ provider_payment_id: providerPaymentId ?? null, idempotency_key: txRef ?? null, payload: data, created_at: new Date().toISOString(), error: 'Missing identifiers' }).catch(() => null)
      return new Response(JSON.stringify({ success: false, error: 'Missing identifiers' }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    // lookup payment: try provider_payment_id, then idempotency_key, then metadata.payment_id
    let payment = null
    let lookupErr = null

    const tryBy = async () => {
      if (providerPaymentId) {
        const { data: p, error } = await supabase.from('payments').select('*').eq('provider_payment_id', providerPaymentId).limit(1).maybeSingle()
        if (p) return p
        if (error) lookupErr = error
      }
      if (txRef) {
        const { data: p2, error: e2 } = await supabase.from('payments').select('*').eq('idempotency_key', txRef).limit(1).maybeSingle()
        if (p2) return p2
        if (e2) lookupErr = e2
      }
      if (data.metadata?.payment_id) {
        const { data: p3, error: e3 } = await supabase.from('payments').select('*').eq('id', data.metadata.payment_id).limit(1).maybeSingle()
        if (p3) return p3
        if (e3) lookupErr = e3
      }
      // fallback: search metadata for provider id
      if (providerPaymentId) {
        const { data: rows } = await supabase.from('payments').select('*').filter('metadata->>provider_payment_id', 'eq', providerPaymentId).limit(1)
        if (rows && rows.length) return rows[0]
      }
      return null
    }

    payment = await tryBy()

    if (!payment) {
      console.warn('Payment not found; logging and returning 404')
      await supabase.from('payment_webhook_logs').insert({ provider_payment_id: providerPaymentId ?? null, idempotency_key: txRef ?? null, payload: data, created_at: new Date().toISOString(), error: 'Payment not found' }).catch(() => null)
      return new Response(JSON.stringify({ success: false, error: 'Payment not found' }), { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    // idempotency: if webhook already processed for this providerPaymentId and status same, return ok
    const existingWebhookStatus = payment?.metadata?.webhook_status
    if (existingWebhookStatus && existingWebhookStatus === webhookStatusRaw) {
      console.log('Webhook already processed with same status; returning 200')
      return new Response(JSON.stringify({ success: true, payment_id: payment.id, skipped: true }), { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    // Map statuses
    const mapStatus = (s) => {
      if (!s) return 'pending'
      const lower = String(s).toLowerCase()
      if (['successful', 'success', 'completed', 'paid'].includes(lower)) return 'completed'
      if (['pending', 'processing', 'in_progress'].includes(lower)) return 'pending'
      if (['failed', 'failed_attempt', 'cancelled', 'canceled'].includes(lower)) return 'failed'
      return 'pending'
    }

    const newStatus = mapStatus(webhookStatusRaw)

    // Merge metadata
    const newMetadata = { ...(payment.metadata || {}), webhook_data: data, processed_at: new Date().toISOString(), webhook_status: webhookStatusRaw }

    const updateObj = { status: newStatus, webhook_received_at: new Date().toISOString(), updated_at: new Date().toISOString(), metadata: newMetadata }

    const { data: updatedPayment, error: updateError } = await supabase.from('payments').update(updateObj).eq('id', payment.id).select().single()
    if (updateError) {
      console.error('Failed to update payment', updateError)
      await supabase.from('payment_webhook_logs').insert({ provider_payment_id: providerPaymentId ?? null, idempotency_key: txRef ?? null, payload: data, created_at: new Date().toISOString(), error: String(updateError) }).catch(() => null)
      return new Response(JSON.stringify({ success: false, error: 'Failed to update payment' }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    // Update order if present
    const orderId = updatedPayment.order_id ?? updatedPayment.order?.id ?? data.metadata?.order_id ?? null
    if (orderId) {
      const orderUpdate = { payment_status: newStatus === 'completed' ? 'paid' : 'failed', updated_at: new Date().toISOString() }
      const { error: orderErr } = await supabase.from('orders').update(orderUpdate).eq('id', orderId).select().single()
      if (orderErr) console.warn('Failed to update order', orderErr)
      else console.log('Order updated for', orderId)

      // broadcast
      try {
        await supabase.channel(`order-${orderId}`).send({ type: 'broadcast', event: 'payment_status_changed', payload: { order_id: orderId, payment_id: updatedPayment.id, status: newStatus, timestamp: new Date().toISOString() } })
      } catch (e) { console.warn('Realtime send failed', e) }
    }

    // log webhook success
    await supabase.from('payment_webhook_logs').insert({ provider_payment_id: providerPaymentId ?? null, idempotency_key: txRef ?? null, payload: data, created_at: new Date().toISOString(), error: null }).catch(() => null)

    return new Response(JSON.stringify({ success: true, payment_id: updatedPayment.id, status: newStatus }), { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })

  } catch (err) {
    console.error('Webhook processing error', err)
    await supabase.from('payment_webhook_logs').insert({ payload: err?.message ?? String(err), created_at: new Date().toISOString(), error: String(err) }).catch(() => null)
    return new Response(JSON.stringify({ success: false, error: String(err) }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
  }
})
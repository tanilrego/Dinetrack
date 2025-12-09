import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.0";

const PAYCHANGU_WEBHOOK_SECRET = Deno.env.get("PAYCHANGU_WEBHOOK_SECRET");
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-paychangu-signature',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

// Verify webhook signature
function verifySignature(payload: string, signature: string): boolean {
  if (!PAYCHANGU_WEBHOOK_SECRET) {
    console.warn("No webhook secret configured, skipping signature verification");
    return true;
  }

  // Implement HMAC verification (adjust based on PayChangu's actual implementation)
  // For now, we'll log and accept (for testing)
  console.log("Webhook signature:", signature);
  console.log("Webhook secret length:", PAYCHANGU_WEBHOOK_SECRET?.length);

  // TODO: Implement actual HMAC verification when PayChangu provides details
  // const expectedSignature = crypto
  //   .createHmac('sha256', PAYCHANGU_WEBHOOK_SECRET)
  //   .update(payload)
  //   .digest('hex');

  // return signature === expectedSignature;

  return true; // Temporarily accept all webhooks for development
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  try {
    const signature = req.headers.get("x-paychangu-signature");
    const payload = await req.text();
    const data = JSON.parse(payload);

    console.log("Webhook received:", JSON.stringify(data, null, 2));

    // Verify webhook signature
    if (!verifySignature(payload, signature || "")) {
      console.error("Invalid webhook signature");
      return new Response("Invalid signature", { status: 401 });
    }

    const providerPaymentId = data.id || data.transaction_id;
    const status = data.status || data.state;
    const amount = data.amount;
    const currency = data.currency;

    if (!providerPaymentId) {
      throw new Error("No provider payment ID in webhook");
    }

    // Find payment record by provider_payment_id
    const { data: payment, error: paymentError } = await supabase
      .from("payments")
      .select("*")
      .eq("provider_payment_id", providerPaymentId)
      .single();

    if (paymentError) {
      // Try finding by metadata
      const { data: payments } = await supabase
        .from("payments")
        .select("*")
        .eq("metadata->>provider_payment_id", providerPaymentId)
        .limit(1);

      if (!payments || payments.length === 0) {
        console.error("Payment not found for provider ID:", providerPaymentId);

        // Log the webhook for manual reconciliation
        await supabase
          .from("payments")
          .insert({
            provider_payment_id: providerPaymentId,
            status: "failed",
            amount: amount ? amount / 100 : 0,
            currency: currency || "MWK",
            metadata: {
              webhook_data: data,
              error: "Payment record not found",
              processed_at: new Date().toISOString()
            }
          });

        return new Response("Payment not found", { status: 404 });
      }

      // Use the found payment
      payment = payments[0];
    }

    console.log("Found payment:", payment.id, "current status:", payment.status);

    // Idempotency check - already processed
    if (payment.status === "completed" && status === "successful") {
      console.log("Payment already completed, ignoring duplicate webhook");
      return new Response("Already processed", { status: 200 });
    }

    // Prepare payment update
    const paymentUpdate: any = {
      status: status === "successful" ? "completed" : "failed",
      webhook_received_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
      metadata: {
        ...payment.metadata,
        webhook_data: data,
        processed_at: new Date().toISOString(),
        webhook_status: status
      }
    };

    // Update payment record
    const { error: updateError } = await supabase
      .from("payments")
      .update(paymentUpdate)
      .eq("id", payment.id);

    if (updateError) {
      console.error("Error updating payment:", updateError);
      throw updateError;
    }

    console.log("Payment updated:", payment.id, "new status:", paymentUpdate.status);

    // If payment successful, update order
    if (status === "successful") {
      console.log("Processing successful payment for order:", payment.order_id);

      // Update order payment status
      const { error: orderUpdateError } = await supabase
        .from("orders")
        .update({
          payment_status: "paid",
          updated_at: new Date().toISOString()
        })
        .eq("id", payment.order_id);

      if (orderUpdateError) {
        console.error("Error updating order:", orderUpdateError);
        throw orderUpdateError;
      }

      console.log("Order updated to paid:", payment.order_id);

      // Send realtime notification
      await supabase.channel(`order-${payment.order_id}`)
        .send({
          type: "broadcast",
          event: "payment_completed",
          payload: {
            order_id: payment.order_id,
            payment_id: payment.id,
            amount: payment.amount,
            provider_payment_id: providerPaymentId,
            timestamp: new Date().toISOString()
          }
        });

      console.log("Realtime notification sent");
    } else if (status === "failed") {
      // Update order payment status to failed
      await supabase
        .from("orders")
        .update({
          payment_status: "failed",
          updated_at: new Date().toISOString()
        })
        .eq("id", payment.order_id);
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: "Webhook processed successfully",
        payment_id: payment.id,
        status: paymentUpdate.status
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200
      }
    );

  } catch (error) {
    console.error("Webhook processing error:", error);

    return new Response(
      JSON.stringify({
        success: false,
        error: error.message,
        timestamp: new Date().toISOString()
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 500
      }
    );
  }
});
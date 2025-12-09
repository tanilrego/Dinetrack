import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.0";

const PAYCHANGU_API_URL = Deno.env.get("PAYCHANGU_API_URL") || "https://api.paychangu.com/v1";
const PAYCHANGU_API_KEY = Deno.env.get("PAYCHANGU_API_KEY");
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, idempotency-key',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const {
      order_id,
      payer_customer_id,
      payment_method = "mobile_money",
      phone_number,
      return_url
    } = await req.json();

    console.log("Creating payment for order:", order_id);

    // Validate required fields
    if (!order_id) {
      throw new Error("order_id is required");
    }
    if (!payer_customer_id) {
      throw new Error("payer_customer_id is required");
    }

    // Validate payment creation using database function
    const { data: validation, error: validationError } = await supabase
      .rpc("validate_payment_creation", {
        p_order_id: order_id,
        p_payer_customer_id: payer_customer_id
      });

    if (validationError) {
      console.error("Validation error:", validationError);
      throw new Error(`Validation failed: ${validationError.message}`);
    }

    if (!validation?.valid) {
      throw new Error(validation?.error || "Invalid payment request");
    }

    const orderData = validation.order;
    const customerData = validation.customer;
    const establishmentData = validation.establishment;

    // Generate idempotency key
    const idempotencyKey = crypto.randomUUID();

    // Create payment record in PENDING state
    const { data: paymentRecord, error: paymentError } = await supabase
      .from("payments")
      .insert({
        order_id: order_id,
        amount: orderData.total_amount,
        payment_method: "paychangu",
        status: "pending",
        currency: "MWK",
        idempotency_key: idempotencyKey,
        payer_customer_id: payer_customer_id,
        metadata: {
          order_number: orderData.order_number,
          table_number: orderData.table_number,
          establishment_name: establishmentData.name,
          customer_email: customerData.email,
          customer_phone: customerData.phone || phone_number,
          payment_method: payment_method,
          validated_at: new Date().toISOString()
        }
      })
      .select()
      .single();

    if (paymentError) {
      console.error("Payment record creation error:", paymentError);

      // Check if it's a duplicate idempotency key error
      if (paymentError.code === "23505" && paymentError.message.includes("idempotency_key")) {
        // Return existing payment
        const { data: existingPayment } = await supabase
          .from("payments")
          .select("*")
          .eq("idempotency_key", idempotencyKey)
          .single();

        if (existingPayment) {
          return new Response(
            JSON.stringify({
              success: true,
              message: "Payment already created",
              payment_id: existingPayment.id,
              checkout_url: existingPayment.checkout_url,
              status: existingPayment.status
            }),
            { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 }
          );
        }
      }
      throw paymentError;
    }

    console.log("Payment record created:", paymentRecord.id);

    // Prepare PayChangu payload
    // Determine the base URL for callbacks/redirects
    const origin = req.headers.get("origin") || "";
    // If client provided a specific return URL (e.g., for deep linking), use it.
    // Otherwise construct one based on the origin.
    const finalReturnUrl = return_url || `${origin}/payment/complete?payment_id=${paymentRecord.id}`;

    const paychanguPayload = {
      amount: Math.round(orderData.total_amount * 100), // Convert to cents
      currency: "MWK",
      payment_method: payment_method === "mobile_money" ? "momo" : payment_method,
      customer: {
        email: customerData.email,
        phone_number: phone_number || customerData.phone,
        name: customerData.full_name || "Customer"
      },
      metadata: {
        payment_id: paymentRecord.id,
        order_id: order_id,
        order_number: orderData.order_number,
        establishment_name: establishmentData.name,
        payer_customer_id: payer_customer_id
      },
      callback_url: `${SUPABASE_URL}/functions/v1/paychangu-webhook`, // Use direct Supabase URL for webhook to ensure it's reachable
      return_url: finalReturnUrl
    };

    console.log("Calling PayChangu API with payload:", JSON.stringify(paychanguPayload, null, 2));

    // Call PayChangu API
    const paychanguResponse = await fetch(`${PAYCHANGU_API_URL}/payments`, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${PAYCHANGU_API_KEY}`,
        "Content-Type": "application/json",
        "Idempotency-Key": idempotencyKey
      },
      body: JSON.stringify(paychanguPayload)
    });

    const paychanguData = await paychanguResponse.json();
    console.log("PayChangu response:", paychanguData);

    if (!paychanguResponse.ok) {
      console.error("PayChangu API error:", paychanguData);

      // Update payment as failed
      await supabase
        .from("payments")
        .update({
          status: "failed",
          metadata: {
            ...paymentRecord.metadata,
            paychangu_error: paychanguData,
            failed_at: new Date().toISOString()
          }
        })
        .eq("id", paymentRecord.id);

      // Update order payment status
      await supabase
        .from("orders")
        .update({ payment_status: "failed" })
        .eq("id", order_id);

      throw new Error(`PayChangu API error: ${JSON.stringify(paychanguData)}`);
    }

    // Update payment with PayChangu details
    await supabase
      .from("payments")
      .update({
        provider_payment_id: paychanguData.id || paychanguData.transaction_id,
        checkout_url: paychanguData.checkout_url || paychanguData.payment_url,
        status: paychanguData.status === "successful" ? "completed" : "pending",
        metadata: {
          ...paymentRecord.metadata,
          paychangu_response: paychanguData,
          provider_payment_id: paychanguData.id || paychanguData.transaction_id
        }
      })
      .eq("id", paymentRecord.id);

    // Update order payment status to processing
    await supabase
      .from("orders")
      .update({ payment_status: "processing" })
      .eq("id", order_id);

    console.log("Payment creation successful:", paymentRecord.id);

    return new Response(
      JSON.stringify({
        success: true,
        payment_id: paymentRecord.id,
        checkout_url: paychanguData.checkout_url || paychanguData.payment_url,
        provider_payment_id: paychanguData.id || paychanguData.transaction_id,
        amount: orderData.total_amount,
        currency: "MWK",
        status: "pending",
        order_number: orderData.order_number
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200
      }
    );

  } catch (error: any) {
    console.error("Error creating payment:", error);

    return new Response(
      JSON.stringify({
        success: false,
        error: error.message || String(error),
        timestamp: new Date().toISOString()
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400
      }
    );
  }
});
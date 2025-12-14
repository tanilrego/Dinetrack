import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.0";

// --- ENVIRONMENT VARIABLES ---
const PAYCHANGU_API_KEY = Deno.env.get("PAYCHANGU_API_KEY");
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";

// Initialize Supabase client with Service Role Key for elevated permissions
const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
const confirmedWebhookUrl = "https://xsflgrmqvnggtdggacrd.supabase.co/functions/v1/paychangu-webhook";

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

    // --- Database Validation (RPC Call) ---
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

    // --- NEW: Phone Number Validation and Cleaning ---
    const phoneToUse = phone_number || customerData.phone;

    if (!phoneToUse) {
      return new Response(
        JSON.stringify({
          success: false,
          error: "Direct charge requires a mobile number. Please log in with a phone number or provide one in the request.",
          timestamp: new Date().toISOString()
        }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 400
        }
      );
    }

    const cleanedMobileNumber = phoneToUse
      .replace(/^\+265/g, "") // Remove starting '+265'
      .replace(/\D/g, "") // Remove any non-digit character (like '+')
      .substring(0, 9); // Ensure it's exactly the local 9 digits

    if (cleanedMobileNumber.length !== 9) {
      return new Response(
        JSON.stringify({
          success: false,
          error: "Mobile number provided is invalid after cleaning. Must be 9 digits (local format).",
          timestamp: new Date().toISOString()
        }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 400
        }
      );
    }
    // --- END Phone Number Validation and Cleaning ---


    // Generate idempotency key
    const idempotencyKey = crypto.randomUUID();

    // --- Create Payment Record (Pending) ---
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
      // Handle duplicate idempotency key error (optional logic)
      if (paymentError.code === "23505" && paymentError.message.includes("idempotency_key")) {
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

    // --- Prepare PayChangu Payload (Using CONFIRMED working structure) ---
    const origin = req.headers.get("origin") || "";
    const finalReturnUrl = return_url || `${origin}/payment/complete?payment_id=${paymentRecord.id}`;

    // Split full name for first_name and last_name fields
    const fullNameParts = customerData.full_name?.split(' ') || [];
    const firstName = fullNameParts[0] || "Customer";
    const lastName = fullNameParts.slice(1).join(' ') || "";

    const paychanguPayload = {
      // Amount must be sent as a STRING and in the smallest unit (tambala/cents)
      amount: Math.round(orderData.total_amount).toString(),
      currency: "MWK",
      // Mobile Money Operator ID for Airtel MoMo - this is required for Direct Charge
      mobile_money_operator_ref_id: "20be6c20-adeb-4b5b-a7ba-0769820df4fb",
      // Use the internal payment ID as the charge_id (IMPORTANT for webhook lookup)
      charge_id: paymentRecord.id,

      // Use the cleaned and validated 9-digit mobile number
      mobile: cleanedMobileNumber,

      email: customerData.email,
      first_name: firstName,
      last_name: lastName,

      callback_url: confirmedWebhookUrl,
      return_url: finalReturnUrl,

      metadata: {
        order_number: orderData.order_number,
        establishment_name: establishmentData.name,
        payer_customer_id: payer_customer_id,
        payment_record_id: paymentRecord.id
      }
    };

    console.log("Calling PayChangu API with payload:", JSON.stringify(paychanguPayload, null, 2));

    // --- Call PayChangu API (USING HARDCODED URL FOR RELIABILITY) ---
    const paychanguResponse = await fetch(`https://api.paychangu.com/mobile-money/payments/initialize`, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${PAYCHANGU_API_KEY}`,
        "Content-Type": "application/json",
        "Idempotency-Key": idempotencyKey
      },
      body: JSON.stringify(paychanguPayload)
    });

    // ----------------------------------------------------
    // *** ERROR HANDLING BLOCK ***
    // ----------------------------------------------------

    // CHECK IF RESPONSE IS NOT OK (Status 4xx or 5xx)
    if (!paychanguResponse.ok) {
      const errorBodyText = await paychanguResponse.text();

      console.error(
        `PayChangu API failed with status ${paychanguResponse.status}. Raw Body:`,
        errorBodyText
      );

      let paychanguErrorDetails: any = {
        status: paychanguResponse.status,
        message: "External API returned an unparsable response.",
        raw_body_start: errorBodyText.substring(0, 500)
      };

      try {
        const parsedJson = JSON.parse(errorBodyText);
        paychanguErrorDetails = parsedJson;
      } catch (e) {
        console.log("Could not parse error response as JSON. It is likely HTML/Text.");
      }

      // Update the payment record as failed
      await supabase
        .from("payments")
        .update({
          status: "failed",
          metadata: {
            ...paymentRecord.metadata,
            paychangu_error: paychanguErrorDetails,
            failed_at: new Date().toISOString(),
          },
        })
        .eq("id", paymentRecord.id);

      await supabase
        .from("orders")
        .update({ payment_status: "failed" })
        .eq("id", order_id);

      // Throw a clean error that returns the details to the client
      throw new Error(`PayChangu API error: ${paychanguResponse.status}. Details: ${JSON.stringify(paychanguErrorDetails)}`);
    }

    // If we reach here, the response is OK (2xx) and should be JSON
    const paychanguData = await paychanguResponse.json();
    console.log("PayChangu response:", paychanguData);

    // Check for success status in the JSON response
    if (paychanguData.status !== "success") {
      console.error("PayChangu reported non-success status:", paychanguData);
      // Treat API-level failures that returned 200 as a failure for our records
      throw new Error(`PayChangu initiated but reported status: ${paychanguData.status}`);
    }

    // --- Update Payment Record (Success Path) ---
    await supabase
      .from("payments")
      .update({
        provider_payment_id: paychanguData.data?.ref_id || paychanguData.ref_id,
        checkout_url: null,
        status: "processing", // Webhook will change to 'completed' or 'failed'
        metadata: {
          ...paymentRecord.metadata,
          paychangu_response: paychanguData,
          provider_payment_id: paychanguData.data?.ref_id || paychanguData.ref_id
        }
      })
      .eq("id", paymentRecord.id);

    // Update order payment status to processing
    await supabase
      .from("orders")
      .update({ payment_status: "processing" })
      .eq("id", order_id);

    console.log("Payment initiation successful:", paymentRecord.id);

    return new Response(
      JSON.stringify({
        success: true,
        payment_id: paymentRecord.id,
        checkout_url: null,
        provider_payment_id: paychanguData.data?.ref_id || paychanguData.ref_id,
        amount: orderData.total_amount,
        currency: "MWK",
        status: "processing",
        order_number: orderData.order_number
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200
      }
    );

  } catch (error: any) {
    console.error("Error creating payment:", error);

    // Final catch block to ensure a structured response to the client
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
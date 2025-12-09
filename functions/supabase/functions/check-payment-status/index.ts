import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.0";

const PAYCHANGU_API_URL = Deno.env.get("PAYCHANGU_API_URL") || "https://api.paychangu.com/v1";
const PAYCHANGU_API_KEY = Deno.env.get("PAYCHANGU_API_KEY");
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { payment_id } = await req.json();

    if (!payment_id) {
      throw new Error("payment_id is required");
    }

    console.log("Checking payment status for:", payment_id);

    // Get payment from database
    const { data: payment, error: paymentError } = await supabase
      .from("payments")
      .select(`
        *,
        order:orders(
          id,
          order_number,
          total_amount,
          payment_status,
          establishment:establishments(name)
        )
      `)
      .eq("id", payment_id)
      .single();

    if (paymentError) {
      console.error("Payment not found:", paymentError);
      throw new Error("Payment not found");
    }

    console.log("Payment found, current status:", payment.status);

    // If already completed or failed, return current status
    if (payment.status === "completed" || payment.status === "failed") {
      return new Response(
        JSON.stringify({
          success: true,
          status: payment.status,
          provider_payment_id: payment.provider_payment_id,
          amount: payment.amount,
          currency: payment.currency,
          order: payment.order,
          updated_at: payment.updated_at,
          checked_at: new Date().toISOString()
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Check with PayChangu API for latest status if we have provider_payment_id
    if (payment.provider_payment_id) {
      console.log("Checking with PayChangu API for:", payment.provider_payment_id);

      try {
        const paychanguResponse = await fetch(
          `${PAYCHANGU_API_URL}/payments/${payment.provider_payment_id}`,
          {
            headers: {
              "Authorization": `Bearer ${PAYCHANGU_API_KEY}`,
              "Content-Type": "application/json"
            }
          }
        );

        if (paychanguResponse.ok) {
          const paychanguData = await paychanguResponse.json();
          console.log("PayChangu API response:", paychanguData);

          const providerStatus = paychanguData.status || paychanguData.state;
          const newStatus = providerStatus === "successful" ? "completed" :
                           providerStatus === "failed" ? "failed" : payment.status;

          // Update database if status changed
          if (newStatus !== payment.status) {
            console.log("Updating payment status from", payment.status, "to", newStatus);

            const updateData: any = {
              status: newStatus,
              updated_at: new Date().toISOString(),
              metadata: {
                ...payment.metadata,
                last_status_check: new Date().toISOString(),
                provider_status: providerStatus,
                paychangu_response: paychanguData
              }
            };

            await supabase
              .from("payments")
              .update(updateData)
              .eq("id", payment.id);

            // If now completed, update order
            if (newStatus === "completed") {
              await supabase
                .from("orders")
                .update({
                  payment_status: "paid",
                  updated_at: new Date().toISOString()
                })
                .eq("id", payment.order_id);
            } else if (newStatus === "failed") {
              await supabase
                .from("orders")
                .update({
                  payment_status: "failed",
                  updated_at: new Date().toISOString()
                })
                .eq("id", payment.order_id);
            }
          }

          return new Response(
            JSON.stringify({
              success: true,
              status: newStatus,
              provider_status: providerStatus,
              provider_payment_id: payment.provider_payment_id,
              amount: payment.amount,
              currency: payment.currency,
              order: payment.order,
              updated_at: new Date().toISOString(),
              checked_at: new Date().toISOString(),
              from_provider: true
            }),
            { headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        } else {
          console.warn("PayChangu API check failed:", paychanguResponse.status);
        }
      } catch (apiError) {
        console.warn("Error checking PayChangu API:", apiError);
        // Continue with current status
      }
    }

    // Return current status if unable to check with provider
    return new Response(
      JSON.stringify({
        success: true,
        status: payment.status,
        provider_payment_id: payment.provider_payment_id,
        amount: payment.amount,
        currency: payment.currency,
        order: payment.order,
        updated_at: payment.updated_at,
        checked_at: new Date().toISOString(),
        from_provider: false
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error) {
    console.error("Error checking payment status:", error);

    return new Response(
      JSON.stringify({
        success: false,
        error: error.message,
        timestamp: new Date().toISOString()
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400
      }
    );
  }
});
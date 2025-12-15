import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.0";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

serve(async (req) => {
    if (req.method === "OPTIONS") {
        return new Response("ok", { headers: corsHeaders });
    }

    try {
        const { establishment_id, payment_id, order_id, subscription_id } = await req.json();

        if (!establishment_id) {
            throw new Error("Missing establishment_id");
        }
        if (!payment_id && !order_id) {
            throw new Error("Missing payment_id or order_id");
        }

        console.log(`Activating subscription for Est: ${establishment_id}, Payment: ${payment_id || 'lookup via order'} (Order: ${order_id})`);

        let targetPaymentId = payment_id;

        // If provided order_id but no payment_id, find the successful payment
        if (!targetPaymentId && order_id) {
            const { data: payments, error: searchError } = await supabase
                .from("payments")
                .select("id")
                .eq("order_id", order_id)
                .in("status", ["completed", "paid"])
                .order("created_at", { ascending: false })
                .limit(1);

            if (searchError) {
                console.error("Error searching payment:", searchError);
                throw new Error("Error searching for payment record");
            }

            if (!payments || payments.length === 0) {
                throw new Error("No successful payment found for this order");
            }
            targetPaymentId = payments[0].id;
            console.log(`Found successful payment ${targetPaymentId} for order ${order_id}`);
        }

        // 1. Verify Payment
        const { data: payment, error: paymentError } = await supabase
            .from("payments")
            .select("status, order_id")
            .eq("id", targetPaymentId)
            .single();

        if (paymentError || !payment) {
            throw new Error("Payment not found");
        }

        if (payment.status !== 'completed' && payment.status !== 'paid') {
            throw new Error(`Payment status is ${payment.status}, expected completed`);
        }

        // 2. Verify Order links to Establishment
        const { data: order, error: orderError } = await supabase
            .from("orders")
            .select("establishment_id")
            .eq("id", payment.order_id)
            .single();

        if (orderError || !order) {
            throw new Error("Associated order not found");
        }

        if (order.establishment_id !== establishment_id) {
            throw new Error("Payment does not belong to this establishment");
        }

        // 3. Activate Establishment
        const { error: updateError } = await supabase
            .from("establishments")
            .update({
                is_active: true,
            })
            .eq("id", establishment_id);

        if (updateError) {
            throw new Error("Failed to activate establishment: " + updateError.message);
        }

        // 4. Update Subscription (if provided)
        if (subscription_id) {
            const startDate = new Date();
            const endDate = new Date();
            endDate.setDate(endDate.getDate() + 30); // 30 days validity

            const { error: subError } = await supabase
                .from("subscriptions")
                .update({
                    status: 'active',
                    start_date: startDate.toISOString(),
                    end_date: endDate.toISOString(),
                    payment_id: targetPaymentId,
                    updated_at: new Date().toISOString()
                })
                .eq("id", subscription_id);

            if (subError) {
                console.error("Failed to update subscription record:", subError);
                // We don't throw here because main activation succeeded
            } else {
                console.log(`Subscription ${subscription_id} activated successfully.`);
            }
        }

        return new Response(
            JSON.stringify({ success: true, message: "Subscription activated successfully" }),
            { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 }
        );

    } catch (error) {
        console.error("Activation error:", error);
        return new Response(
            JSON.stringify({ success: false, error: error.message }),
            { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 400 }
        );
    }
});

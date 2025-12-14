import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.0";

// --- GLOBAL CORS HEADERS (FIXED) ---
const corsHeaders = {
    // Allows any origin (including your localhost) to access the resource
    'Access-Control-Allow-Origin': '*',
    // Declares which headers the client can send
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    // Declares which methods are allowed for the preflight check
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

// --- HELPER FUNCTION TO RESPOND WITH JSON AND HEADERS ---
function createResponse(body: Record<string, any>, status: number) {
    return new Response(
        JSON.stringify(body),
        {
            headers: {
                ...corsHeaders,
                "Content-Type": "application/json"
            },
            status: status,
        }
    );
}

serve(async (req) => {
    // 1. Handle CORS preflight request (OPTIONS)
    if (req.method === 'OPTIONS') {
        return createResponse({ message: 'CORS Preflight OK' }, 200);
    }

    try {
        const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "";
        const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";

        if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
            throw new Error("Missing Supabase configuration");
        }

        const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

        const { payment_id, order_id } = await req.json();

        if (!payment_id || !order_id) {
            throw new Error("payment_id and order_id are required details");
        }

        console.log(`Approving test payment: ${payment_id} for order: ${order_id}`);

        // 1. Check current payment status for idempotency (Good Practice)
        const { data: currentPayment, error: fetchError } = await supabase
            .from("payments")
            .select("status")
            .eq("id", payment_id)
            .single();

        if (fetchError || !currentPayment) {
            throw new Error("Payment record not found.");
        }

        if (currentPayment.status === "completed") {
            return createResponse({
                success: true,
                message: "Payment already completed"
            }, 200);
        }

        // 2. Update Payment Status to completed
        const { error: paymentError } = await supabase
            .from("payments")
            .update({
                status: "completed",
                updated_at: new Date().toISOString(),
                // Use metadata field to clearly mark it as a test bypass
                metadata: {
                    manual_approval: true,
                    approved_at: new Date().toISOString()
                }
            })
            .eq("id", payment_id)
            .select(); // Add .select() to ensure the update occurs correctly

        if (paymentError) {
            console.error("Payment update failed:", paymentError);
            throw new Error(`Payment update failed: ${paymentError.message}`);
        }

        // 3. Update Order Status to paid
        const { error: orderError } = await supabase
            .from("orders")
            .update({
                payment_status: "paid",
                status: "confirmed",
                updated_at: new Date().toISOString()
            })
            .eq("id", order_id);

        if (orderError) {
            console.error("Order update failed:", orderError);
            throw new Error(`Order update failed: ${orderError.message}`);
        }

        console.log("Test payment successfully approved.");

        return createResponse({
            success: true,
            message: "Test payment approved successfully"
        }, 200);

    } catch (error) {
        // 4. Handle errors and ensure CORS headers are still returned
        const message = error instanceof Error ? error.message : "An unknown error occurred.";
        return createResponse({ success: false, error: message }, 400);
    }
});
-- Create subscriptions table
CREATE TABLE IF NOT EXISTS public.subscriptions (
    id uuid NOT NULL DEFAULT uuid_generate_v4(),
    establishment_id uuid NOT NULL,
    plan_type text NOT NULL DEFAULT 'monthly' CHECK (plan_type IN ('monthly', 'yearly')),
    status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'active', 'expired', 'cancelled')),
    start_date timestamp with time zone DEFAULT now(),
    end_date timestamp with time zone,
    amount numeric NOT NULL,
    payment_id uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    
    CONSTRAINT subscriptions_pkey PRIMARY KEY (id),
    CONSTRAINT subscriptions_establishment_id_fkey FOREIGN KEY (establishment_id) REFERENCES public.establishments(id) ON DELETE CASCADE,
    CONSTRAINT subscriptions_payment_id_fkey FOREIGN KEY (payment_id) REFERENCES public.payments(id)
);

-- Enable RLS
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Establishment owners can view their subscriptions" 
ON public.subscriptions
FOR SELECT 
USING (
    establishment_id IN (
        SELECT id FROM public.establishments WHERE owner_id = auth.uid()
    )
);

CREATE POLICY "Service Role can manage all" 
ON public.subscriptions
FOR ALL 
TO service_role 
USING (true) 
WITH CHECK (true);

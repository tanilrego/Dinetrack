-- Create reservations table
CREATE TABLE IF NOT EXISTS public.reservations (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    establishment_id uuid NOT NULL REFERENCES public.establishments(id) ON DELETE CASCADE,
    table_id uuid REFERENCES public.tables(id) ON DELETE SET NULL,
    user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL, -- Optional, if logged in customer
    client_name text NOT NULL,
    client_phone text NOT NULL,
    client_email text,
    reservation_time timestamp with time zone NOT NULL,
    party_size int NOT NULL DEFAULT 2,
    status text NOT NULL DEFAULT 'pending', -- pending, confirmed, cancelled, completed
    notes text,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- RLS Policies
ALTER TABLE public.reservations ENABLE ROW LEVEL SECURITY;

-- Allow public to create reservations (anyone can book)
CREATE POLICY "Allow public insert reservations" ON public.reservations FOR INSERT WITH CHECK (true);

-- Allow users to view their own reservations (by user_id)
CREATE POLICY "Allow users to view own reservations" ON public.reservations FOR SELECT USING (auth.uid() = user_id);

-- Allow establishment owners/staff to view/update reservations for their establishment
-- This is complex because we need to join staff/establishments. 
-- For simplicity in MVP, we might allow authenticated users to read? No, that exposes data.
-- We rely on service_role for admin/kitchen dashboards or proper complex policies.
-- Let's add a basic policy for reading if you are the creator or owner (simplified).
CREATE POLICY "Allow read for establishment owners" ON public.reservations FOR SELECT 
USING (
  establishment_id IN (
    SELECT id FROM public.establishments WHERE owner_id = auth.uid()
  )
);

-- Allow read for staff (checking staff_assignments)
CREATE POLICY "Allow read for staff" ON public.reservations FOR SELECT
USING (
  establishment_id IN (
    SELECT establishment_id FROM public.staff_assignments WHERE user_id = auth.uid()
  )
);

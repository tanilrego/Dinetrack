-- Enable RLS on payments table (if not already enabled)
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;

-- Policy: Allow users to insert their own payment records
CREATE POLICY "Users can create their own payments"
ON payments
FOR INSERT
TO authenticated
WITH CHECK (
  payer_customer_id = auth.uid()
);

-- Policy: Allow users to view their own payment records
CREATE POLICY "Users can view their own payments"
ON payments
FOR SELECT
TO authenticated
USING (
  payer_customer_id = auth.uid()
);

-- Policy: Allow users to update their own pending payments
CREATE POLICY "Users can update their own pending payments"
ON payments
FOR UPDATE
TO authenticated
USING (
  payer_customer_id = auth.uid() AND status = 'pending'
)
WITH CHECK (
  payer_customer_id = auth.uid()
);

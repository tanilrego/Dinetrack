-- Create validation function for payment creation
CREATE OR REPLACE FUNCTION validate_payment_creation(
  p_order_id UUID,
  p_payer_customer_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_order RECORD;
  v_customer RECORD;
  v_establishment RECORD;
  v_result JSON;
BEGIN
  -- Fetch order with all necessary details
  SELECT 
    o.id,
    o.total_amount,
    o.status,
    o.payment_status,
    o.table_no as table_number,
    o.customer_id,
    o.establishment_id,
    COALESCE(o.order_number, o.id::text) as order_number
  INTO v_order
  FROM orders o
  WHERE o.id = p_order_id;

  -- Check if order exists
  IF NOT FOUND THEN
    RETURN json_build_object(
      'valid', false,
      'error', 'Order not found'
    );
  END IF;

  -- Check if customer is authorized for this order
  IF v_order.customer_id != p_payer_customer_id THEN
    RETURN json_build_object(
      'valid', false,
      'error', 'Unauthorized: Customer does not own this order'
    );
  END IF;

  -- Check if order is already paid
  IF v_order.payment_status = 'paid' THEN
    RETURN json_build_object(
      'valid', false,
      'error', 'Order has already been paid'
    );
  END IF;

  -- Fetch customer details
  SELECT 
    id,
    email,
    full_name,
    phone
  INTO v_customer
  FROM users
  WHERE id = p_payer_customer_id;

  IF NOT FOUND THEN
    RETURN json_build_object(
      'valid', false,
      'error', 'Customer not found'
    );
  END IF;

  -- Fetch establishment details
  SELECT 
    id,
    name
  INTO v_establishment
  FROM establishments
  WHERE id = v_order.establishment_id;

  IF NOT FOUND THEN
    RETURN json_build_object(
      'valid', false,
      'error', 'Establishment not found'
    );
  END IF;

  -- Build successful response with all necessary data
  RETURN json_build_object(
    'valid', true,
    'order', json_build_object(
      'id', v_order.id,
      'total_amount', v_order.total_amount,
      'status', v_order.status,
      'payment_status', v_order.payment_status,
      'table_number', v_order.table_number,
      'order_number', v_order.order_number,
      'customer_id', v_order.customer_id,
      'establishment_id', v_order.establishment_id
    ),
    'customer', json_build_object(
      'id', v_customer.id,
      'email', v_customer.email,
      'full_name', v_customer.full_name,
      'phone', v_customer.phone
    ),
    'establishment', json_build_object(
      'id', v_establishment.id,
      'name', v_establishment.name
    )
  );
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION validate_payment_creation(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION validate_payment_creation(UUID, UUID) TO service_role;

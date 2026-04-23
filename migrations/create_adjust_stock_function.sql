-- Migration: Create adjust_stock function
-- Purpose: Manually adjust inventory stock with reason tracking
-- Updates opening_quantity and logs adjustment record
-- Run in Supabase SQL Editor

CREATE OR REPLACE FUNCTION adjust_stock(
    p_item_id UUID,
    p_new_quantity NUMERIC,
    p_reason TEXT,
    p_adjustment_type TEXT DEFAULT 'correction'
)
RETURNS VOID AS $$
DECLARE
    v_current_opening NUMERIC;
    v_expected_stock NUMERIC;
BEGIN
    -- Get current opening quantity
    SELECT COALESCE(opening_quantity, 0) INTO v_current_opening
    FROM inventory_items
    WHERE id = p_item_id;
    
    -- Get current expected stock (opening - used)
    SELECT expected_stock INTO v_expected_stock
    FROM inventory_stock_view
    WHERE id = p_item_id;
    
    -- Validate adjustment type
    IF p_adjustment_type NOT IN ('loss', 'gain', 'correction') THEN
        RAISE EXCEPTION 'Invalid adjustment type: %', p_adjustment_type;
    END IF;
    
    -- Update opening quantity to new value
    UPDATE inventory_items
    SET opening_quantity = p_new_quantity,
        updated_at = NOW()
    WHERE id = p_item_id;
    
    -- Log adjustment
    INSERT INTO inventory_adjustments (
        item_id,
        previous_quantity,
        new_quantity,
        reason,
        adjustment_type,
        adjusted_by
    ) VALUES (
        p_item_id,
        v_current_opening,
        p_new_quantity,
        p_reason,
        p_adjustment_type,
        auth.uid()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Add comment for documentation
COMMENT ON FUNCTION adjust_stock(p_item_id UUID, p_new_quantity NUMERIC, p_reason TEXT, p_adjustment_type TEXT) IS 'Manually adjusts inventory stock with reason tracking and audit trail';

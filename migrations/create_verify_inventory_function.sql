-- Migration: Create verify_inventory function
-- Purpose: Handle physical stock verification and mismatch detection
-- Compares actual vs expected and determines status (OK/LOSS/EXTRA)
-- Run in Supabase SQL Editor

CREATE OR REPLACE FUNCTION verify_inventory(p_item_id UUID, p_actual NUMERIC)
RETURNS VOID AS $$
DECLARE
    v_expected NUMERIC;
    v_diff NUMERIC;
    v_status TEXT;
BEGIN
    -- Get expected stock from view
    SELECT expected_stock INTO v_expected
    FROM inventory_stock_view
    WHERE id = p_item_id;

    -- Calculate difference
    v_diff := p_actual - COALESCE(v_expected, 0);

    -- Determine status
    IF v_diff < -2 THEN
        v_status := 'LOSS';
    ELSIF v_diff > 2 THEN
        v_status := 'EXTRA';
    ELSE
        v_status := 'OK';
    END IF;

    -- Insert verification record
    INSERT INTO inventory_verifications (
        item_id,
        actual_quantity,
        expected_quantity,
        difference,
        status,
        verified_by,
        verified_at
    ) VALUES (
        p_item_id,
        p_actual,
        COALESCE(v_expected, 0),
        v_diff,
        v_status,
        auth.uid(),
        NOW()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Add comment for documentation
COMMENT ON FUNCTION verify_inventory(p_item_id UUID, p_actual NUMERIC) IS 'Records physical stock verification and detects mismatches';

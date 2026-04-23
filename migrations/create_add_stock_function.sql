-- Migration: Create add_stock function
-- Purpose: Add stock to inventory and record purchase
-- Updates opening_quantity and logs purchase transaction
-- Run in Supabase SQL Editor

CREATE OR REPLACE FUNCTION add_stock(
    p_item_id UUID,
    p_quantity NUMERIC,
    p_price_per_unit NUMERIC,
    p_purchase_date DATE DEFAULT CURRENT_DATE,
    p_supplier_name TEXT DEFAULT NULL,
    p_invoice_number TEXT DEFAULT NULL,
    p_notes TEXT DEFAULT NULL
)
RETURNS VOID AS $$
DECLARE
    v_current_opening NUMERIC;
BEGIN
    -- Get current opening quantity
    SELECT COALESCE(opening_quantity, 0) INTO v_current_opening
    FROM inventory_items
    WHERE id = p_item_id;
    
    -- Update opening quantity (add new stock to existing)
    UPDATE inventory_items
    SET opening_quantity = v_current_opening + p_quantity,
        updated_at = NOW()
    WHERE id = p_item_id;
    
    -- Record purchase
    INSERT INTO inventory_purchases (
        item_id,
        quantity,
        price_per_unit,
        purchase_date,
        supplier_name,
        invoice_number,
        notes,
        created_by
    ) VALUES (
        p_item_id,
        p_quantity,
        p_price_per_unit,
        p_purchase_date,
        p_supplier_name,
        p_invoice_number,
        p_notes,
        auth.uid()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Add comment for documentation
COMMENT ON FUNCTION add_stock(p_item_id UUID, p_quantity NUMERIC, p_price_per_unit NUMERIC, p_purchase_date DATE, p_supplier_name TEXT, p_invoice_number TEXT, p_notes TEXT) IS 'Adds stock to inventory and records purchase transaction';

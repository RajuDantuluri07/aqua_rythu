-- Migration: Extend add_stock RPC to accept pack-based purchases
-- Purpose: Farmer enters "8 bags @ ₹2200/bag" → system converts to raw quantity
-- and records the pack snapshot on inventory_purchases.
-- Backward-compatible: existing callers passing only quantity/price_per_unit still work.
-- Run AFTER add_pack_fields_to_inventory.sql.

DROP FUNCTION IF EXISTS add_stock(UUID, NUMERIC, NUMERIC, DATE, TEXT, TEXT, TEXT);

CREATE OR REPLACE FUNCTION add_stock(
    p_item_id UUID,
    p_quantity NUMERIC DEFAULT NULL,
    p_price_per_unit NUMERIC DEFAULT NULL,
    p_purchase_date DATE DEFAULT CURRENT_DATE,
    p_supplier_name TEXT DEFAULT NULL,
    p_invoice_number TEXT DEFAULT NULL,
    p_notes TEXT DEFAULT NULL,
    p_packs NUMERIC DEFAULT NULL,
    p_cost_per_pack NUMERIC DEFAULT NULL
)
RETURNS VOID AS $$
DECLARE
    v_current_opening NUMERIC;
    v_pack_size NUMERIC;
    v_quantity NUMERIC;
    v_price_per_unit NUMERIC;
    v_cost_per_pack NUMERIC;
BEGIN
    -- Load item state
    SELECT COALESCE(opening_quantity, 0), pack_size
      INTO v_current_opening, v_pack_size
    FROM inventory_items
    WHERE id = p_item_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Inventory item % not found', p_item_id;
    END IF;

    -- Resolve quantity: prefer pack-based input when provided
    IF p_packs IS NOT NULL AND v_pack_size IS NOT NULL THEN
        v_quantity := p_packs * v_pack_size;
        v_cost_per_pack := p_cost_per_pack;
        v_price_per_unit := CASE
            WHEN p_cost_per_pack IS NOT NULL AND v_pack_size > 0
                THEN p_cost_per_pack / v_pack_size
            ELSE p_price_per_unit
        END;
    ELSE
        v_quantity := p_quantity;
        v_price_per_unit := p_price_per_unit;
        v_cost_per_pack := CASE
            WHEN v_pack_size IS NOT NULL AND p_price_per_unit IS NOT NULL
                THEN p_price_per_unit * v_pack_size
            ELSE p_cost_per_pack
        END;
    END IF;

    IF v_quantity IS NULL OR v_quantity <= 0 THEN
        RAISE EXCEPTION 'Quantity must be > 0 (got %)', v_quantity;
    END IF;

    -- Increment stock
    UPDATE inventory_items
    SET opening_quantity = v_current_opening + v_quantity,
        updated_at = NOW()
    WHERE id = p_item_id;

    -- Record purchase with pack snapshot
    INSERT INTO inventory_purchases (
        item_id,
        quantity,
        price_per_unit,
        purchase_date,
        supplier_name,
        invoice_number,
        notes,
        created_by,
        packs,
        pack_size_at_purchase,
        cost_per_pack
    ) VALUES (
        p_item_id,
        v_quantity,
        COALESCE(v_price_per_unit, 0),
        p_purchase_date,
        p_supplier_name,
        p_invoice_number,
        p_notes,
        auth.uid(),
        p_packs,
        v_pack_size,
        v_cost_per_pack
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION add_stock(UUID, NUMERIC, NUMERIC, DATE, TEXT, TEXT, TEXT, NUMERIC, NUMERIC) IS
    'Adds stock to inventory and records purchase. Accepts either raw quantity+price_per_unit or packs+cost_per_pack.';

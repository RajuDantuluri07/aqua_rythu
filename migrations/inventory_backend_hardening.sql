-- Migration: Inventory Backend Hardening (Final Lock)
-- Purpose: Enforce critical business rules and add missing safety features
-- Run in Supabase SQL Editor

-- TASK 1: ENFORCE SINGLE FEED ITEM PER CROP
-- Create unique index to prevent duplicate feed items for same crop
CREATE UNIQUE INDEX IF NOT EXISTS one_feed_per_crop 
ON inventory_items (crop_id) 
WHERE category = 'feed' AND is_auto_tracked = TRUE;

-- Add comment for documentation
COMMENT ON INDEX one_feed_per_crop IS 'Ensures only one auto-tracked feed item per crop';

-- TASK 2: CONFIRM SAFE FEED MAPPING LOGIC
-- Update the feed inventory function to use safe mapping (ignore feed_type)
CREATE OR REPLACE FUNCTION handle_feed_inventory()
RETURNS TRIGGER AS $$
DECLARE
    feed_item_id UUID;
BEGIN
    -- Safe mapping: Always get first feed item for crop, ignore feed_type
    SELECT id INTO feed_item_id
    FROM inventory_items
    WHERE crop_id = NEW.crop_id
      AND category = 'feed'
      AND is_auto_tracked = TRUE
    LIMIT 1;

    -- Only proceed if we found a feed inventory item
    IF feed_item_id IS NOT NULL THEN
        -- Insert consumption record
        INSERT INTO inventory_consumption (
            item_id,
            quantity_used,
            source,
            reference_id,
            date
        ) VALUES (
            feed_item_id,
            COALESCE(NEW.feed_quantity, NEW.feed_given, 0),
            'feed_auto',
            NEW.id,
            NEW.date::DATE
        );
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- TASK 3: ADD NEGATIVE STOCK HANDLING TO VIEW
-- Update inventory_stock_view to include negative stock flag
CREATE OR REPLACE VIEW inventory_stock_view AS
SELECT
    i.id,
    i.name,
    i.category,
    i.unit,
    i.crop_id,
    i.farm_id,
    i.opening_quantity,
    i.price_per_unit,
    i.is_auto_tracked,
    i.created_at,
    i.updated_at,
    COALESCE(SUM(c.quantity_used), 0) as total_used,
    (i.opening_quantity - COALESCE(SUM(c.quantity_used), 0)) as expected_stock,
    CASE 
        WHEN (i.opening_quantity - COALESCE(SUM(c.quantity_used), 0)) < 0 THEN 'NEGATIVE'
        WHEN (i.opening_quantity - COALESCE(SUM(c.quantity_used), 0)) <= 2 THEN 'LOW'
        ELSE 'OK'
    END as stock_status,
    CASE 
        WHEN (i.opening_quantity - COALESCE(SUM(c.quantity_used), 0)) < 0 THEN TRUE
        ELSE FALSE
    END as is_negative
FROM inventory_items i
LEFT JOIN inventory_consumption c ON i.id = c.item_id
GROUP BY 
    i.id, i.name, i.category, i.unit, i.crop_id, i.farm_id, 
    i.opening_quantity, i.price_per_unit, i.is_auto_tracked, 
    i.created_at, i.updated_at;

-- TASK 4: VALIDATE VERIFICATION STATUS LOGIC
-- The verification function is already correct, just add safety check
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

    -- Determine status (already correct logic)
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

-- TASK 5: ADD VERIFICATION TRACKING HELPERS
-- Add function to get latest verification date for an item
CREATE OR REPLACE FUNCTION get_latest_verification_date(p_item_id UUID)
RETURNS TIMESTAMP AS $$
DECLARE
    v_latest_verification TIMESTAMP;
BEGIN
    SELECT verified_at INTO v_latest_verification
    FROM inventory_verifications
    WHERE item_id = p_item_id
    ORDER BY verified_at DESC
    LIMIT 1;
    
    RETURN v_latest_verification;
END;
$$ LANGUAGE plpgsql;

-- Add function to check if verification is overdue (5+ days)
CREATE OR REPLACE FUNCTION is_verification_overdue(p_item_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    v_latest_verification TIMESTAMP;
    v_days_since_verification INTEGER;
BEGIN
    v_latest_verification := get_latest_verification_date(p_item_id);
    
    IF v_latest_verification IS NULL THEN
        -- Never verified
        RETURN TRUE;
    END IF;
    
    v_days_since_verification := EXTRACT(DAYS FROM NOW() - v_latest_verification);
    
    RETURN v_days_since_verification >= 5;
END;
$$ LANGUAGE plpgsql;

-- Update view to include verification status
CREATE OR REPLACE VIEW inventory_stock_view AS
SELECT
    i.id,
    i.name,
    i.category,
    i.unit,
    i.crop_id,
    i.farm_id,
    i.opening_quantity,
    i.price_per_unit,
    i.is_auto_tracked,
    i.created_at,
    i.updated_at,
    COALESCE(SUM(c.quantity_used), 0) as total_used,
    (i.opening_quantity - COALESCE(SUM(c.quantity_used), 0)) as expected_stock,
    CASE 
        WHEN (i.opening_quantity - COALESCE(SUM(c.quantity_used), 0)) < 0 THEN 'NEGATIVE'
        WHEN (i.opening_quantity - COALESCE(SUM(c.quantity_used), 0)) <= 2 THEN 'LOW'
        ELSE 'OK'
    END as stock_status,
    CASE 
        WHEN (i.opening_quantity - COALESCE(SUM(c.quantity_used), 0)) < 0 THEN TRUE
        ELSE FALSE
    END as is_negative,
    get_latest_verification_date(i.id) as latest_verification,
    is_verification_overdue(i.id) as verification_overdue
FROM inventory_items i
LEFT JOIN inventory_consumption c ON i.id = c.item_id
GROUP BY 
    i.id, i.name, i.category, i.unit, i.crop_id, i.farm_id, 
    i.opening_quantity, i.price_per_unit, i.is_auto_tracked, 
    i.created_at, i.updated_at;

-- Add comments for documentation
COMMENT ON FUNCTION get_latest_verification_date(p_item_id UUID) IS 'Returns the latest verification date for an inventory item';
COMMENT ON FUNCTION is_verification_overdue(p_item_id UUID) IS 'Returns TRUE if verification is 5+ days overdue';
COMMENT ON COLUMN inventory_stock_view.is_negative IS 'TRUE when expected stock is below zero';
COMMENT ON COLUMN inventory_stock_view.latest_verification IS 'Date of last physical verification';
COMMENT ON COLUMN inventory_stock_view.verification_overdue IS 'TRUE when verification is 5+ days overdue';

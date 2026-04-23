-- Migration: Enhance inventory_stock_view for stock mismatch and last actions
-- Purpose: Add stock mismatch visibility and last action tracking
-- Run in Supabase SQL Editor

-- Create helper function to get last action type and date
CREATE OR REPLACE FUNCTION get_last_stock_action(p_item_id UUID)
RETURNS TABLE(action_type TEXT, action_date TIMESTAMP, action_details TEXT) AS $$
BEGIN
    RETURN QUERY
    WITH last_actions AS (
        -- Get last purchase
        SELECT 
            'purchase' as action_type,
            purchase_date as action_date,
            'Bought ' || quantity::TEXT || ' @ ₹' || price_per_unit::TEXT as action_details,
            1 as priority
        FROM inventory_purchases 
        WHERE item_id = p_item_id
        
        UNION ALL
        
        -- Get last adjustment
        SELECT 
            'adjustment' as action_type,
            adjusted_at as action_date,
            adjustment_type || ': ' || reason as action_details,
            2 as priority
        FROM inventory_adjustments 
        WHERE item_id = p_item_id
        
        UNION ALL
        
        -- Get last verification
        SELECT 
            'verification' as action_type,
            verified_at as action_date,
            status || ' (diff: ' || difference::TEXT || ')' as action_details,
            3 as priority
        FROM inventory_verifications 
        WHERE item_id = p_item_id
    )
    SELECT action_type, action_date, action_details
    FROM last_actions
    ORDER BY action_date DESC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- Update inventory_stock_view with enhanced features
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
    is_verification_overdue(i.id) as verification_overdue,
    
    -- Stock mismatch visibility
    (SELECT actual_quantity FROM inventory_verifications 
     WHERE item_id = i.id 
     ORDER BY verified_at DESC 
     LIMIT 1) as last_verified_quantity,
     
    -- Calculate difference between expected and last verified
    (i.opening_quantity - COALESCE(SUM(c.quantity_used), 0)) - 
    COALESCE((SELECT actual_quantity FROM inventory_verifications 
              WHERE item_id = i.id 
              ORDER BY verified_at DESC 
              LIMIT 1), i.opening_quantity - COALESCE(SUM(c.quantity_used), 0)) as stock_difference,
    
    -- Last action tracking
    (SELECT action_type FROM get_last_stock_action(i.id) LIMIT 1) as last_action_type,
    (SELECT action_date FROM get_last_stock_action(i.id) LIMIT 1) as last_action_date,
    (SELECT action_details FROM get_last_stock_action(i.id) LIMIT 1) as last_action_details
    
FROM inventory_items i
LEFT JOIN inventory_consumption c ON i.id = c.item_id
GROUP BY 
    i.id, i.name, i.category, i.unit, i.crop_id, i.farm_id, 
    i.opening_quantity, i.price_per_unit, i.is_auto_tracked, 
    i.created_at, i.updated_at;

-- Add comments for documentation
COMMENT ON COLUMN inventory_stock_view.last_verified_quantity IS 'Most recent physically verified quantity';
COMMENT ON COLUMN inventory_stock_view.stock_difference IS 'Expected stock - last verified quantity';
COMMENT ON COLUMN inventory_stock_view.last_action_type IS 'Last action: purchase, adjustment, or verification';
COMMENT ON COLUMN inventory_stock_view.last_action_date IS 'Date of last action on this item';
COMMENT ON COLUMN inventory_stock_view.last_action_details IS 'Details of last action (e.g., purchase amount, adjustment reason)';

-- Migration: Create inventory_stock_view
-- Purpose: Real-time calculation of expected inventory levels
-- Combines opening stock with all consumption to show current expected quantity
-- Run in Supabase SQL Editor

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
    END as stock_status
FROM inventory_items i
LEFT JOIN inventory_consumption c ON i.id = c.item_id
GROUP BY 
    i.id, i.name, i.category, i.unit, i.crop_id, i.farm_id, 
    i.opening_quantity, i.price_per_unit, i.is_auto_tracked, 
    i.created_at, i.updated_at;

-- Add comment for documentation
COMMENT ON VIEW inventory_stock_view IS 'Real-time inventory levels with consumption tracking';
COMMENT ON COLUMN inventory_stock_view.total_used IS 'Total quantity consumed from opening stock';
COMMENT ON COLUMN inventory_stock_view.expected_stock IS 'Current expected inventory level';
COMMENT ON COLUMN inventory_stock_view.stock_status IS 'NEGATIVE, LOW (<=2), OK';

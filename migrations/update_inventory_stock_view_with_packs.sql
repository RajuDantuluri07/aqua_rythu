-- Migration: Extend inventory_stock_view with pack-based fields
-- Purpose: Surface remaining_packs, total_packs, pack_label, pack_size, cost_per_pack
-- and a category-aware pack_status (GOOD / LOW / CRITICAL / NEGATIVE) for the UI.
-- Replaces the view from enhance_inventory_stock_view.sql; depends on
-- inventory_backend_hardening.sql for verification helpers.
-- Run AFTER add_pack_fields_to_inventory.sql.

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

    -- Pack metadata
    i.pack_size,
    i.pack_label,
    i.cost_per_pack,

    -- Consumption / expected stock
    COALESCE(SUM(c.quantity_used), 0) AS total_used,
    (i.opening_quantity - COALESCE(SUM(c.quantity_used), 0)) AS expected_stock,

    -- Pack-derived counts (NULL when pack_size not set)
    CASE WHEN i.pack_size IS NULL OR i.pack_size = 0 THEN NULL
         ELSE i.opening_quantity / i.pack_size
    END AS total_packs,
    CASE WHEN i.pack_size IS NULL OR i.pack_size = 0 THEN NULL
         ELSE (i.opening_quantity - COALESCE(SUM(c.quantity_used), 0)) / i.pack_size
    END AS remaining_packs,

    -- Original status (kept for back-compat with old code paths)
    CASE
        WHEN (i.opening_quantity - COALESCE(SUM(c.quantity_used), 0)) < 0 THEN 'NEGATIVE'
        WHEN (i.opening_quantity - COALESCE(SUM(c.quantity_used), 0)) <= 2 THEN 'LOW'
        ELSE 'OK'
    END AS stock_status,

    -- Category-aware pack status (farmer-facing)
    -- Feed: <5 kg = CRITICAL, <10 kg = LOW
    -- Others: <2 unit = LOW (no critical tier in v1)
    CASE
        WHEN (i.opening_quantity - COALESCE(SUM(c.quantity_used), 0)) < 0 THEN 'NEGATIVE'
        WHEN i.category = 'feed' AND (i.opening_quantity - COALESCE(SUM(c.quantity_used), 0)) < 5 THEN 'CRITICAL'
        WHEN i.category = 'feed' AND (i.opening_quantity - COALESCE(SUM(c.quantity_used), 0)) < 10 THEN 'LOW'
        WHEN i.category <> 'feed' AND (i.opening_quantity - COALESCE(SUM(c.quantity_used), 0)) <= 2 THEN 'LOW'
        ELSE 'GOOD'
    END AS pack_status,

    CASE
        WHEN (i.opening_quantity - COALESCE(SUM(c.quantity_used), 0)) < 0 THEN TRUE
        ELSE FALSE
    END AS is_negative,

    get_latest_verification_date(i.id) AS latest_verification,
    is_verification_overdue(i.id) AS verification_overdue,

    -- Stock mismatch
    (SELECT actual_quantity FROM inventory_verifications
     WHERE item_id = i.id
     ORDER BY verified_at DESC
     LIMIT 1) AS last_verified_quantity,

    (i.opening_quantity - COALESCE(SUM(c.quantity_used), 0)) -
    COALESCE((SELECT actual_quantity FROM inventory_verifications
              WHERE item_id = i.id
              ORDER BY verified_at DESC
              LIMIT 1), i.opening_quantity - COALESCE(SUM(c.quantity_used), 0)) AS stock_difference,

    -- Last action
    (SELECT action_type FROM get_last_stock_action(i.id) LIMIT 1) AS last_action_type,
    (SELECT action_date FROM get_last_stock_action(i.id) LIMIT 1) AS last_action_date,
    (SELECT action_details FROM get_last_stock_action(i.id) LIMIT 1) AS last_action_details

FROM inventory_items i
LEFT JOIN inventory_consumption c ON i.id = c.item_id
GROUP BY
    i.id, i.name, i.category, i.unit, i.crop_id, i.farm_id,
    i.opening_quantity, i.price_per_unit, i.is_auto_tracked,
    i.pack_size, i.pack_label, i.cost_per_pack,
    i.created_at, i.updated_at;

COMMENT ON COLUMN inventory_stock_view.total_packs IS 'opening_quantity / pack_size (NULL if pack_size unset)';
COMMENT ON COLUMN inventory_stock_view.remaining_packs IS 'expected_stock / pack_size — fractional packs allowed (e.g., 3.4)';
COMMENT ON COLUMN inventory_stock_view.pack_status IS 'NEGATIVE | CRITICAL | LOW | GOOD — category-aware thresholds';

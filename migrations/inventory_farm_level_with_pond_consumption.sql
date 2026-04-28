-- Migration: Move inventory to farm level, add per-pond consumption tracking
-- inventory_items are now created at farm level (crop_id IS NULL).
-- inventory_consumption gains pond_id so per-pond feed usage is queryable.
-- Trigger updated to look up farm's feed item via ponds.farm_id.
-- Backward-compat: old per-pond items (crop_id = pond_id) still deduct correctly.

-- 1. Add pond_id to inventory_consumption for per-pond breakdown
ALTER TABLE inventory_consumption
  ADD COLUMN IF NOT EXISTS pond_id UUID REFERENCES ponds(id) ON DELETE SET NULL;

-- 2. Update trigger: resolve farm from pond, write pond_id on consumption
CREATE OR REPLACE FUNCTION handle_feed_inventory_deduction()
RETURNS TRIGGER AS $$
DECLARE
    v_item_id UUID;
    v_farm_id UUID;
BEGIN
    IF NEW.feed_given IS NULL OR NEW.feed_given <= 0 THEN RETURN NEW; END IF;

    SELECT farm_id INTO v_farm_id FROM ponds WHERE id = NEW.pond_id LIMIT 1;
    IF v_farm_id IS NULL THEN RETURN NEW; END IF;

    -- Farm-level item first (crop_id IS NULL)
    SELECT id INTO v_item_id
    FROM inventory_items
    WHERE farm_id = v_farm_id
      AND category = 'feed'
      AND is_auto_tracked = true
      AND crop_id IS NULL
    LIMIT 1;

    -- Fallback: legacy per-pond item
    IF v_item_id IS NULL THEN
        SELECT id INTO v_item_id
        FROM inventory_items
        WHERE crop_id = NEW.pond_id
          AND category = 'feed'
          AND is_auto_tracked = true
        LIMIT 1;
    END IF;

    IF v_item_id IS NULL THEN RETURN NEW; END IF;

    IF EXISTS (
        SELECT 1 FROM inventory_consumption
        WHERE reference_id = NEW.id AND source = 'feed_auto'
    ) THEN RETURN NEW; END IF;

    INSERT INTO inventory_consumption (item_id, quantity_used, source, reference_id, date, pond_id)
    VALUES (v_item_id, NEW.feed_given, 'feed_auto', NEW.id, CURRENT_DATE, NEW.pond_id);

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. inventory_stock_view: unchanged structure, now naturally aggregates all-pond usage
CREATE OR REPLACE VIEW inventory_stock_view AS
SELECT
    i.id, i.name, i.category, i.unit, i.crop_id, i.farm_id,
    i.opening_quantity, i.price_per_unit, i.is_auto_tracked,
    i.created_at, i.updated_at, i.pack_size, i.pack_label, i.cost_per_pack,

    COALESCE(SUM(c.quantity_used), 0)                              AS total_used,
    (i.opening_quantity - COALESCE(SUM(c.quantity_used), 0))       AS expected_stock,

    CASE WHEN i.pack_size IS NULL OR i.pack_size = 0 THEN NULL
         ELSE i.opening_quantity / i.pack_size END                 AS total_packs,
    CASE WHEN i.pack_size IS NULL OR i.pack_size = 0 THEN NULL
         ELSE (i.opening_quantity - COALESCE(SUM(c.quantity_used), 0)) / i.pack_size
    END                                                            AS remaining_packs,

    CASE
        WHEN (i.opening_quantity - COALESCE(SUM(c.quantity_used), 0)) < 0 THEN 'NEGATIVE'
        WHEN (i.opening_quantity - COALESCE(SUM(c.quantity_used), 0)) <= 2 THEN 'LOW'
        ELSE 'OK'
    END AS stock_status,

    CASE
        WHEN (i.opening_quantity - COALESCE(SUM(c.quantity_used), 0)) < 0 THEN 'NEGATIVE'
        WHEN i.category = 'feed' AND (i.opening_quantity - COALESCE(SUM(c.quantity_used), 0)) < 5  THEN 'CRITICAL'
        WHEN i.category = 'feed' AND (i.opening_quantity - COALESCE(SUM(c.quantity_used), 0)) < 10 THEN 'LOW'
        WHEN i.category <> 'feed' AND (i.opening_quantity - COALESCE(SUM(c.quantity_used), 0)) <= 2 THEN 'LOW'
        ELSE 'GOOD'
    END AS pack_status,

    CASE WHEN (i.opening_quantity - COALESCE(SUM(c.quantity_used), 0)) < 0 THEN TRUE ELSE FALSE END AS is_negative,

    get_latest_verification_date(i.id) AS latest_verification,
    is_verification_overdue(i.id)      AS verification_overdue,

    (SELECT actual_quantity FROM inventory_verifications
     WHERE item_id = i.id ORDER BY verified_at DESC LIMIT 1)      AS last_verified_quantity,

    (i.opening_quantity - COALESCE(SUM(c.quantity_used), 0)) -
    COALESCE((SELECT actual_quantity FROM inventory_verifications
              WHERE item_id = i.id ORDER BY verified_at DESC LIMIT 1),
             i.opening_quantity - COALESCE(SUM(c.quantity_used), 0)) AS stock_difference,

    (SELECT action_type    FROM get_last_stock_action(i.id) LIMIT 1) AS last_action_type,
    (SELECT action_date    FROM get_last_stock_action(i.id) LIMIT 1) AS last_action_date,
    (SELECT action_details FROM get_last_stock_action(i.id) LIMIT 1) AS last_action_details

FROM inventory_items i
LEFT JOIN inventory_consumption c ON i.id = c.item_id
GROUP BY i.id, i.name, i.category, i.unit, i.crop_id, i.farm_id,
         i.opening_quantity, i.price_per_unit, i.is_auto_tracked,
         i.pack_size, i.pack_label, i.cost_per_pack,
         i.created_at, i.updated_at;

-- 4. Per-pond feed usage breakdown view
CREATE OR REPLACE VIEW inventory_pond_usage_view AS
SELECT
    c.item_id,
    c.pond_id,
    p.name               AS pond_name,
    SUM(c.quantity_used) AS total_used,
    MAX(c.date)          AS last_used_date
FROM inventory_consumption c
JOIN ponds p ON p.id = c.pond_id
WHERE c.pond_id IS NOT NULL
GROUP BY c.item_id, c.pond_id, p.name;

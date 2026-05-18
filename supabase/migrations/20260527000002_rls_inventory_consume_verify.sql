-- Enable RLS on inventory_consumption and inventory_verifications.
-- Both tables were accessible to any authenticated user. Ownership chain:
--   item_id → inventory_items.farm_id → farms.user_id = auth.uid()

-- ── inventory_consumption ─────────────────────────────────────────────────────
ALTER TABLE inventory_consumption ENABLE ROW LEVEL SECURITY;

CREATE POLICY "inv_consumption_select_owner" ON inventory_consumption
  FOR SELECT USING (
    item_id IN (
      SELECT ii.id FROM inventory_items ii
      JOIN farms f ON ii.farm_id = f.id
      WHERE f.user_id = auth.uid()
    )
  );

CREATE POLICY "inv_consumption_insert_owner" ON inventory_consumption
  FOR INSERT WITH CHECK (
    item_id IN (
      SELECT ii.id FROM inventory_items ii
      JOIN farms f ON ii.farm_id = f.id
      WHERE f.user_id = auth.uid()
    )
  );

CREATE POLICY "inv_consumption_update_owner" ON inventory_consumption
  FOR UPDATE USING (
    item_id IN (
      SELECT ii.id FROM inventory_items ii
      JOIN farms f ON ii.farm_id = f.id
      WHERE f.user_id = auth.uid()
    )
  );

CREATE POLICY "inv_consumption_delete_owner" ON inventory_consumption
  FOR DELETE USING (
    item_id IN (
      SELECT ii.id FROM inventory_items ii
      JOIN farms f ON ii.farm_id = f.id
      WHERE f.user_id = auth.uid()
    )
  );

-- ── inventory_verifications ───────────────────────────────────────────────────
ALTER TABLE inventory_verifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "inv_verif_select_owner" ON inventory_verifications
  FOR SELECT USING (
    item_id IN (
      SELECT ii.id FROM inventory_items ii
      JOIN farms f ON ii.farm_id = f.id
      WHERE f.user_id = auth.uid()
    )
  );

CREATE POLICY "inv_verif_insert_owner" ON inventory_verifications
  FOR INSERT WITH CHECK (
    item_id IN (
      SELECT ii.id FROM inventory_items ii
      JOIN farms f ON ii.farm_id = f.id
      WHERE f.user_id = auth.uid()
    )
  );

CREATE POLICY "inv_verif_update_owner" ON inventory_verifications
  FOR UPDATE USING (
    item_id IN (
      SELECT ii.id FROM inventory_items ii
      JOIN farms f ON ii.farm_id = f.id
      WHERE f.user_id = auth.uid()
    )
  );

CREATE POLICY "inv_verif_delete_owner" ON inventory_verifications
  FOR DELETE USING (
    item_id IN (
      SELECT ii.id FROM inventory_items ii
      JOIN farms f ON ii.farm_id = f.id
      WHERE f.user_id = auth.uid()
    )
  );

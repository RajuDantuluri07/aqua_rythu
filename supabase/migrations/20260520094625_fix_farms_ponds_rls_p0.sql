-- Drop all existing policy name variants on farms and ponds,
-- then recreate with simple direct ownership checks.
-- Removes the compound is_farm_admin + user_id check from ponds_insert
-- (pond creation always goes through the SECURITY DEFINER RPC).

-- ── FARMS ─────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "farms_select"        ON farms;
DROP POLICY IF EXISTS "farms_insert"        ON farms;
DROP POLICY IF EXISTS "farms_update"        ON farms;
DROP POLICY IF EXISTS "farms_delete"        ON farms;
DROP POLICY IF EXISTS "farms_select_owner"  ON farms;
DROP POLICY IF EXISTS "farms_insert_owner"  ON farms;
DROP POLICY IF EXISTS "farms_update_owner"  ON farms;
DROP POLICY IF EXISTS "farms_delete_owner"  ON farms;

ALTER TABLE farms ENABLE ROW LEVEL SECURITY;

CREATE POLICY "farms_select_owner" ON farms
  FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR is_farm_member(id));

CREATE POLICY "farms_insert_owner" ON farms
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "farms_update_owner" ON farms
  FOR UPDATE TO authenticated
  USING  (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "farms_delete_owner" ON farms
  FOR DELETE TO authenticated
  USING (user_id = auth.uid());

-- ── PONDS ─────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "ponds_select"        ON ponds;
DROP POLICY IF EXISTS "ponds_insert"        ON ponds;
DROP POLICY IF EXISTS "ponds_update"        ON ponds;
DROP POLICY IF EXISTS "ponds_delete"        ON ponds;
DROP POLICY IF EXISTS "ponds_select_owner"  ON ponds;
DROP POLICY IF EXISTS "ponds_insert_owner"  ON ponds;
DROP POLICY IF EXISTS "ponds_update_owner"  ON ponds;
DROP POLICY IF EXISTS "ponds_delete_owner"  ON ponds;

ALTER TABLE ponds ENABLE ROW LEVEL SECURITY;

CREATE POLICY "ponds_select_owner" ON ponds
  FOR SELECT TO authenticated
  USING (is_farm_member(farm_id));

CREATE POLICY "ponds_insert_owner" ON ponds
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM farms
      WHERE farms.id = ponds.farm_id
        AND farms.user_id = auth.uid()
    )
  );

CREATE POLICY "ponds_update_owner" ON ponds
  FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM farms
      WHERE farms.id = ponds.farm_id
        AND farms.user_id = auth.uid()
    )
  );

CREATE POLICY "ponds_delete_owner" ON ponds
  FOR DELETE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM farms
      WHERE farms.id = ponds.farm_id
        AND farms.user_id = auth.uid()
    )
  );

-- RLS for core agricultural tables: farms, ponds, feed_rounds, feed_logs,
-- feed_plans, samplings, tray_statuses, water_logs, harvests, expenses.
--
-- Pattern: every table that hangs off a farm is protected via an
-- auth.uid() → farms ownership chain so no explicit user_id column is
-- required on every table.

-- ───────────────────────────────────────────────
-- FARMS
-- ───────────────────────────────────────────────
ALTER TABLE farms ENABLE ROW LEVEL SECURITY;

CREATE POLICY "farms_select_owner" ON farms
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "farms_insert_owner" ON farms
  FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "farms_update_owner" ON farms
  FOR UPDATE USING (user_id = auth.uid());

CREATE POLICY "farms_delete_owner" ON farms
  FOR DELETE USING (user_id = auth.uid());

-- ───────────────────────────────────────────────
-- PONDS  (owned by farm → user)
-- ───────────────────────────────────────────────
ALTER TABLE ponds ENABLE ROW LEVEL SECURITY;

CREATE POLICY "ponds_select_owner" ON ponds
  FOR SELECT USING (
    farm_id IN (SELECT id FROM farms WHERE user_id = auth.uid())
  );

CREATE POLICY "ponds_insert_owner" ON ponds
  FOR INSERT WITH CHECK (
    farm_id IN (SELECT id FROM farms WHERE user_id = auth.uid())
  );

CREATE POLICY "ponds_update_owner" ON ponds
  FOR UPDATE USING (
    farm_id IN (SELECT id FROM farms WHERE user_id = auth.uid())
  );

CREATE POLICY "ponds_delete_owner" ON ponds
  FOR DELETE USING (
    farm_id IN (SELECT id FROM farms WHERE user_id = auth.uid())
  );

-- ───────────────────────────────────────────────
-- FEED_ROUNDS  (owned by pond → farm → user)
-- ───────────────────────────────────────────────
ALTER TABLE feed_rounds ENABLE ROW LEVEL SECURITY;

CREATE POLICY "feed_rounds_select_owner" ON feed_rounds
  FOR SELECT USING (
    pond_id IN (
      SELECT p.id FROM ponds p
      JOIN farms f ON p.farm_id = f.id
      WHERE f.user_id = auth.uid()
    )
  );

CREATE POLICY "feed_rounds_insert_owner" ON feed_rounds
  FOR INSERT WITH CHECK (
    pond_id IN (
      SELECT p.id FROM ponds p
      JOIN farms f ON p.farm_id = f.id
      WHERE f.user_id = auth.uid()
    )
  );

CREATE POLICY "feed_rounds_update_owner" ON feed_rounds
  FOR UPDATE USING (
    pond_id IN (
      SELECT p.id FROM ponds p
      JOIN farms f ON p.farm_id = f.id
      WHERE f.user_id = auth.uid()
    )
  );

CREATE POLICY "feed_rounds_delete_owner" ON feed_rounds
  FOR DELETE USING (
    pond_id IN (
      SELECT p.id FROM ponds p
      JOIN farms f ON p.farm_id = f.id
      WHERE f.user_id = auth.uid()
    )
  );

-- ───────────────────────────────────────────────
-- FEED_LOGS  (owned by pond → farm → user)
-- ───────────────────────────────────────────────
ALTER TABLE feed_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "feed_logs_select_owner" ON feed_logs
  FOR SELECT USING (
    pond_id IN (
      SELECT p.id FROM ponds p
      JOIN farms f ON p.farm_id = f.id
      WHERE f.user_id = auth.uid()
    )
  );

CREATE POLICY "feed_logs_insert_owner" ON feed_logs
  FOR INSERT WITH CHECK (
    pond_id IN (
      SELECT p.id FROM ponds p
      JOIN farms f ON p.farm_id = f.id
      WHERE f.user_id = auth.uid()
    )
  );

CREATE POLICY "feed_logs_update_owner" ON feed_logs
  FOR UPDATE USING (
    pond_id IN (
      SELECT p.id FROM ponds p
      JOIN farms f ON p.farm_id = f.id
      WHERE f.user_id = auth.uid()
    )
  );

CREATE POLICY "feed_logs_delete_owner" ON feed_logs
  FOR DELETE USING (
    pond_id IN (
      SELECT p.id FROM ponds p
      JOIN farms f ON p.farm_id = f.id
      WHERE f.user_id = auth.uid()
    )
  );

-- ───────────────────────────────────────────────
-- FEED_PLANS  (owned by pond → farm → user)
-- ───────────────────────────────────────────────
ALTER TABLE feed_plans ENABLE ROW LEVEL SECURITY;

CREATE POLICY "feed_plans_select_owner" ON feed_plans
  FOR SELECT USING (
    pond_id IN (
      SELECT p.id FROM ponds p
      JOIN farms f ON p.farm_id = f.id
      WHERE f.user_id = auth.uid()
    )
  );

CREATE POLICY "feed_plans_insert_owner" ON feed_plans
  FOR INSERT WITH CHECK (
    pond_id IN (
      SELECT p.id FROM ponds p
      JOIN farms f ON p.farm_id = f.id
      WHERE f.user_id = auth.uid()
    )
  );

CREATE POLICY "feed_plans_update_owner" ON feed_plans
  FOR UPDATE USING (
    pond_id IN (
      SELECT p.id FROM ponds p
      JOIN farms f ON p.farm_id = f.id
      WHERE f.user_id = auth.uid()
    )
  );

-- ───────────────────────────────────────────────
-- SAMPLINGS  (owned by pond → farm → user)
-- ───────────────────────────────────────────────
ALTER TABLE samplings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "samplings_select_owner" ON samplings
  FOR SELECT USING (
    pond_id IN (
      SELECT p.id FROM ponds p
      JOIN farms f ON p.farm_id = f.id
      WHERE f.user_id = auth.uid()
    )
  );

CREATE POLICY "samplings_insert_owner" ON samplings
  FOR INSERT WITH CHECK (
    pond_id IN (
      SELECT p.id FROM ponds p
      JOIN farms f ON p.farm_id = f.id
      WHERE f.user_id = auth.uid()
    )
  );

CREATE POLICY "samplings_update_owner" ON samplings
  FOR UPDATE USING (
    pond_id IN (
      SELECT p.id FROM ponds p
      JOIN farms f ON p.farm_id = f.id
      WHERE f.user_id = auth.uid()
    )
  );

CREATE POLICY "samplings_delete_owner" ON samplings
  FOR DELETE USING (
    pond_id IN (
      SELECT p.id FROM ponds p
      JOIN farms f ON p.farm_id = f.id
      WHERE f.user_id = auth.uid()
    )
  );

-- ───────────────────────────────────────────────
-- TRAY_STATUSES  (owned by pond → farm → user)
-- ───────────────────────────────────────────────
ALTER TABLE tray_statuses ENABLE ROW LEVEL SECURITY;

CREATE POLICY "tray_statuses_select_owner" ON tray_statuses
  FOR SELECT USING (
    pond_id IN (
      SELECT p.id FROM ponds p
      JOIN farms f ON p.farm_id = f.id
      WHERE f.user_id = auth.uid()
    )
  );

CREATE POLICY "tray_statuses_insert_owner" ON tray_statuses
  FOR INSERT WITH CHECK (
    pond_id IN (
      SELECT p.id FROM ponds p
      JOIN farms f ON p.farm_id = f.id
      WHERE f.user_id = auth.uid()
    )
  );

CREATE POLICY "tray_statuses_update_owner" ON tray_statuses
  FOR UPDATE USING (
    pond_id IN (
      SELECT p.id FROM ponds p
      JOIN farms f ON p.farm_id = f.id
      WHERE f.user_id = auth.uid()
    )
  );

CREATE POLICY "tray_statuses_delete_owner" ON tray_statuses
  FOR DELETE USING (
    pond_id IN (
      SELECT p.id FROM ponds p
      JOIN farms f ON p.farm_id = f.id
      WHERE f.user_id = auth.uid()
    )
  );

-- ───────────────────────────────────────────────
-- WATER_LOGS  (owned by pond → farm → user)
-- ───────────────────────────────────────────────
ALTER TABLE water_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "water_logs_select_owner" ON water_logs
  FOR SELECT USING (
    pond_id IN (
      SELECT p.id FROM ponds p
      JOIN farms f ON p.farm_id = f.id
      WHERE f.user_id = auth.uid()
    )
  );

CREATE POLICY "water_logs_insert_owner" ON water_logs
  FOR INSERT WITH CHECK (
    pond_id IN (
      SELECT p.id FROM ponds p
      JOIN farms f ON p.farm_id = f.id
      WHERE f.user_id = auth.uid()
    )
  );

CREATE POLICY "water_logs_update_owner" ON water_logs
  FOR UPDATE USING (
    pond_id IN (
      SELECT p.id FROM ponds p
      JOIN farms f ON p.farm_id = f.id
      WHERE f.user_id = auth.uid()
    )
  );

CREATE POLICY "water_logs_delete_owner" ON water_logs
  FOR DELETE USING (
    pond_id IN (
      SELECT p.id FROM ponds p
      JOIN farms f ON p.farm_id = f.id
      WHERE f.user_id = auth.uid()
    )
  );

-- ───────────────────────────────────────────────
-- HARVESTS  (owned by crop_id via ponds)
-- ───────────────────────────────────────────────
ALTER TABLE harvests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "harvests_select_owner" ON harvests
  FOR SELECT USING (
    crop_id IN (
      SELECT p.id FROM ponds p
      JOIN farms f ON p.farm_id = f.id
      WHERE f.user_id = auth.uid()
    )
  );

CREATE POLICY "harvests_insert_owner" ON harvests
  FOR INSERT WITH CHECK (
    crop_id IN (
      SELECT p.id FROM ponds p
      JOIN farms f ON p.farm_id = f.id
      WHERE f.user_id = auth.uid()
    )
  );

CREATE POLICY "harvests_update_owner" ON harvests
  FOR UPDATE USING (
    crop_id IN (
      SELECT p.id FROM ponds p
      JOIN farms f ON p.farm_id = f.id
      WHERE f.user_id = auth.uid()
    )
  );

CREATE POLICY "harvests_delete_owner" ON harvests
  FOR DELETE USING (
    crop_id IN (
      SELECT p.id FROM ponds p
      JOIN farms f ON p.farm_id = f.id
      WHERE f.user_id = auth.uid()
    )
  );

-- ───────────────────────────────────────────────
-- EXPENSES  (has user_id column — direct check)
-- ───────────────────────────────────────────────
ALTER TABLE expenses ENABLE ROW LEVEL SECURITY;

CREATE POLICY "expenses_select_owner" ON expenses
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "expenses_insert_owner" ON expenses
  FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "expenses_update_owner" ON expenses
  FOR UPDATE USING (user_id = auth.uid());

CREATE POLICY "expenses_delete_owner" ON expenses
  FOR DELETE USING (user_id = auth.uid());

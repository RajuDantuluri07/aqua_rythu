-- Enable RLS on crop_cycles and profiles.
-- crop_cycles was missing RLS entirely — any authenticated user could read/write
-- all farms' cycle data. profiles exposed user PII (name, phone, email) cross-account.

-- ── crop_cycles ───────────────────────────────────────────────────────────────
ALTER TABLE crop_cycles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "crop_cycles_select_owner" ON crop_cycles
  FOR SELECT USING (
    farm_id IN (
      SELECT id FROM farms WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "crop_cycles_insert_owner" ON crop_cycles
  FOR INSERT WITH CHECK (
    farm_id IN (
      SELECT id FROM farms WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "crop_cycles_update_owner" ON crop_cycles
  FOR UPDATE USING (
    farm_id IN (
      SELECT id FROM farms WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "crop_cycles_delete_owner" ON crop_cycles
  FOR DELETE USING (
    farm_id IN (
      SELECT id FROM farms WHERE user_id = auth.uid()
    )
  );

-- ── profiles ──────────────────────────────────────────────────────────────────
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "profiles_select_own" ON profiles
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "profiles_insert_own" ON profiles
  FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "profiles_update_own" ON profiles
  FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "profiles_delete_own" ON profiles
  FOR DELETE USING (auth.uid() = id);

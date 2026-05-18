-- Fix missing RLS on harvest_logs and tray_logs.
-- The core RLS migration protected 'harvests' and 'tray_statuses' by name,
-- but the app writes to 'harvest_logs' and 'tray_logs'. Without RLS these
-- tables were publicly readable/writable across all users.

ALTER TABLE harvest_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "harvest_logs_select_owner" ON harvest_logs
  FOR SELECT USING (
    pond_id IN (
      SELECT p.id FROM ponds p
      JOIN farms f ON p.farm_id = f.id
      WHERE f.user_id = auth.uid()
    )
  );

CREATE POLICY "harvest_logs_insert_owner" ON harvest_logs
  FOR INSERT WITH CHECK (
    pond_id IN (
      SELECT p.id FROM ponds p
      JOIN farms f ON p.farm_id = f.id
      WHERE f.user_id = auth.uid()
    )
  );

CREATE POLICY "harvest_logs_update_owner" ON harvest_logs
  FOR UPDATE USING (
    pond_id IN (
      SELECT p.id FROM ponds p
      JOIN farms f ON p.farm_id = f.id
      WHERE f.user_id = auth.uid()
    )
  );

CREATE POLICY "harvest_logs_delete_owner" ON harvest_logs
  FOR DELETE USING (
    pond_id IN (
      SELECT p.id FROM ponds p
      JOIN farms f ON p.farm_id = f.id
      WHERE f.user_id = auth.uid()
    )
  );

ALTER TABLE tray_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "tray_logs_select_owner" ON tray_logs
  FOR SELECT USING (
    pond_id IN (
      SELECT p.id FROM ponds p
      JOIN farms f ON p.farm_id = f.id
      WHERE f.user_id = auth.uid()
    )
  );

CREATE POLICY "tray_logs_insert_owner" ON tray_logs
  FOR INSERT WITH CHECK (
    pond_id IN (
      SELECT p.id FROM ponds p
      JOIN farms f ON p.farm_id = f.id
      WHERE f.user_id = auth.uid()
    )
  );

CREATE POLICY "tray_logs_update_owner" ON tray_logs
  FOR UPDATE USING (
    pond_id IN (
      SELECT p.id FROM ponds p
      JOIN farms f ON p.farm_id = f.id
      WHERE f.user_id = auth.uid()
    )
  );

CREATE POLICY "tray_logs_delete_owner" ON tray_logs
  FOR DELETE USING (
    pond_id IN (
      SELECT p.id FROM ponds p
      JOIN farms f ON p.farm_id = f.id
      WHERE f.user_id = auth.uid()
    )
  );

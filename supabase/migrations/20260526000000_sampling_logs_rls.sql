-- Enable RLS on sampling_logs and gate all operations via the
-- auth.uid() → farms ownership chain (pond_id → ponds → farms).
-- The `samplings` table already had RLS from 20260523000000_rls_core_tables.sql;
-- this migration closes the identical gap on `sampling_logs`.

ALTER TABLE sampling_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "sampling_logs_select_owner" ON sampling_logs
  FOR SELECT USING (
    pond_id IN (
      SELECT p.id FROM ponds p
      JOIN farms f ON p.farm_id = f.id
      WHERE f.user_id = auth.uid()
    )
  );

CREATE POLICY "sampling_logs_insert_owner" ON sampling_logs
  FOR INSERT WITH CHECK (
    pond_id IN (
      SELECT p.id FROM ponds p
      JOIN farms f ON p.farm_id = f.id
      WHERE f.user_id = auth.uid()
    )
  );

CREATE POLICY "sampling_logs_update_owner" ON sampling_logs
  FOR UPDATE USING (
    pond_id IN (
      SELECT p.id FROM ponds p
      JOIN farms f ON p.farm_id = f.id
      WHERE f.user_id = auth.uid()
    )
  );

CREATE POLICY "sampling_logs_delete_owner" ON sampling_logs
  FOR DELETE USING (
    pond_id IN (
      SELECT p.id FROM ponds p
      JOIN farms f ON p.farm_id = f.id
      WHERE f.user_id = auth.uid()
    )
  );

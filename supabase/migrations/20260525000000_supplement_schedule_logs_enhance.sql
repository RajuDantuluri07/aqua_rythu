-- Enhance supplement_schedule_logs with fields needed for persistent application history.
-- Adds pond_id for fast per-pond queries, applied_items JSON for dose detail,
-- and input_value/unit for feed-kg or pond-area context.
--
-- Also enables RLS so each user can only see their own application logs.

ALTER TABLE public.supplement_schedule_logs
  ADD COLUMN IF NOT EXISTS pond_id        UUID REFERENCES public.ponds(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS supplement_name TEXT,
  ADD COLUMN IF NOT EXISTS applied_items  JSONB DEFAULT '[]',
  ADD COLUMN IF NOT EXISTS input_value    NUMERIC,
  ADD COLUMN IF NOT EXISTS input_unit     TEXT,
  ADD COLUMN IF NOT EXISTS created_by     UUID REFERENCES auth.users(id);

-- Fast look-up for per-pond history screen
CREATE INDEX IF NOT EXISTS idx_ssl_pond_date
  ON public.supplement_schedule_logs(pond_id, created_at DESC);

-- ── RLS ────────────────────────────────────────────────────────────────────
ALTER TABLE public.supplement_schedule_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "ssl_select_owner" ON public.supplement_schedule_logs
  FOR SELECT USING (
    pond_id IN (
      SELECT p.id FROM ponds p
      JOIN farms f ON p.farm_id = f.id
      WHERE f.user_id = auth.uid()
    )
  );

CREATE POLICY "ssl_insert_owner" ON public.supplement_schedule_logs
  FOR INSERT WITH CHECK (
    pond_id IN (
      SELECT p.id FROM ponds p
      JOIN farms f ON p.farm_id = f.id
      WHERE f.user_id = auth.uid()
    )
  );

CREATE POLICY "ssl_update_owner" ON public.supplement_schedule_logs
  FOR UPDATE USING (
    pond_id IN (
      SELECT p.id FROM ponds p
      JOIN farms f ON p.farm_id = f.id
      WHERE f.user_id = auth.uid()
    )
  );

CREATE POLICY "ssl_delete_owner" ON public.supplement_schedule_logs
  FOR DELETE USING (
    pond_id IN (
      SELECT p.id FROM ponds p
      JOIN farms f ON p.farm_id = f.id
      WHERE f.user_id = auth.uid()
    )
  );

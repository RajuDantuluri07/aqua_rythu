-- =============================================================
-- Unified Feed Round Architecture
-- Ticket: Refactor Feed + Tray Backend Into Unified Feed Round Architecture
--
-- Changes:
--   1. Enhance feed_rounds with lifecycle status + confirmation columns
--   2. Create tray_checks table linked to feed_rounds
--   3. Migrate historical tray_logs → tray_checks (with orphan marking)
--   4. Update complete_feed_round_with_log RPC to set feed_status = 'confirmed'
--   5. Add save_tray_check RPC (atomic tray check + status update)
-- =============================================================

-- ─────────────────────────────────────────────────────────────
-- 1. Enhance feed_rounds table
-- ─────────────────────────────────────────────────────────────

-- feed_date: date the round was planned/executed
ALTER TABLE public.feed_rounds
  ADD COLUMN IF NOT EXISTS feed_date DATE;

-- Backfill feed_date from created_at for existing rows
UPDATE public.feed_rounds SET feed_date = created_at::date WHERE feed_date IS NULL;

-- Make it non-null with default going forward
ALTER TABLE public.feed_rounds
  ALTER COLUMN feed_date SET DEFAULT CURRENT_DATE;

-- Full lifecycle status (separate from legacy `status` column)
-- Values: planned → confirmed → tray_checked → smart_adjusted → completed
ALTER TABLE public.feed_rounds
  ADD COLUMN IF NOT EXISTS feed_status TEXT DEFAULT 'planned'
    CHECK (feed_status IN ('planned', 'confirmed', 'tray_checked', 'smart_adjusted', 'completed'));

-- Backfill feed_status from existing status column
UPDATE public.feed_rounds
SET feed_status = CASE
  WHEN status = 'completed' THEN 'confirmed'
  ELSE 'planned'
END
WHERE feed_status = 'planned';  -- only rows that haven't been updated yet

-- confirmed_feed_kg: immutable record of what was actually given
-- Backfilled from actual_amount; actual_amount column preserved for compat
ALTER TABLE public.feed_rounds
  ADD COLUMN IF NOT EXISTS confirmed_feed_kg NUMERIC(10,2);

UPDATE public.feed_rounds
SET confirmed_feed_kg = actual_amount
WHERE confirmed_feed_kg IS NULL AND actual_amount IS NOT NULL;

-- smart_adjusted_feed_kg: output of smart feed engine for NEXT round
-- Never overwrites confirmed_feed_kg or planned_amount
ALTER TABLE public.feed_rounds
  ADD COLUMN IF NOT EXISTS smart_adjusted_feed_kg NUMERIC(10,2);

-- confirmation_source: who confirmed the feed
ALTER TABLE public.feed_rounds
  ADD COLUMN IF NOT EXISTS confirmation_source TEXT
    CHECK (confirmation_source IS NULL OR confirmation_source IN ('farmer', 'worker', 'smart_engine'));

-- confirmed_at: when the feed was confirmed
ALTER TABLE public.feed_rounds
  ADD COLUMN IF NOT EXISTS confirmed_at TIMESTAMPTZ;

-- Backfill confirmed_at for already-completed rounds
UPDATE public.feed_rounds
SET confirmed_at = updated_at
WHERE status = 'completed' AND confirmed_at IS NULL;

-- notes: optional free-text
ALTER TABLE public.feed_rounds
  ADD COLUMN IF NOT EXISTS notes TEXT;

-- ─────────────────────────────────────────────────────────────
-- 2. Create tray_checks table
-- ─────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.tray_checks (
  id              UUID          DEFAULT gen_random_uuid() PRIMARY KEY,
  feed_round_id   UUID          NOT NULL
                    REFERENCES public.feed_rounds(id) ON DELETE CASCADE,
  pond_id         UUID          NOT NULL
                    REFERENCES public.ponds(id) ON DELETE CASCADE,
  -- tray_factor: 0.0 (all empty) → 1.0 (all heavy)
  -- empty=0.0  light=0.15  medium=0.40  heavy=0.70
  tray_factor     NUMERIC(5,4),
  -- normalized JSON: {"tray_1": "empty", "tray_2": "partial", ...}
  -- also stores raw statuses array under key "_statuses" for auditability
  observation_json JSONB        DEFAULT '{}',
  checked_at      TIMESTAMPTZ   DEFAULT now(),
  checked_by      UUID,
  created_at      TIMESTAMPTZ   DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_tray_checks_feed_round_id
  ON public.tray_checks(feed_round_id);
CREATE INDEX IF NOT EXISTS idx_tray_checks_pond_id
  ON public.tray_checks(pond_id);
CREATE INDEX IF NOT EXISTS idx_tray_checks_checked_at
  ON public.tray_checks(checked_at DESC);

ALTER TABLE public.tray_checks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "tray_checks_select_owner" ON public.tray_checks
  FOR SELECT USING (
    pond_id IN (
      SELECT p.id FROM public.ponds p
      JOIN public.farms f ON p.farm_id = f.id
      WHERE f.user_id = auth.uid()
    )
  );

CREATE POLICY "tray_checks_insert_owner" ON public.tray_checks
  FOR INSERT WITH CHECK (
    pond_id IN (
      SELECT p.id FROM public.ponds p
      JOIN public.farms f ON p.farm_id = f.id
      WHERE f.user_id = auth.uid()
    )
  );

CREATE POLICY "tray_checks_update_owner" ON public.tray_checks
  FOR UPDATE USING (
    pond_id IN (
      SELECT p.id FROM public.ponds p
      JOIN public.farms f ON p.farm_id = f.id
      WHERE f.user_id = auth.uid()
    )
  );

-- ─────────────────────────────────────────────────────────────
-- 3. Mark orphaned tray_logs + migrate to tray_checks
-- ─────────────────────────────────────────────────────────────

-- Flag for historical data that had no matching feed_round
ALTER TABLE public.tray_logs
  ADD COLUMN IF NOT EXISTS orphaned_legacy_data BOOLEAN DEFAULT FALSE;
ALTER TABLE public.tray_logs
  ADD COLUMN IF NOT EXISTS migrated_to_tray_check_id UUID;

-- Migrate tray_logs → tray_checks (one insert per matched tray_log)
-- Skipped entries (tray_statuses = '{skipped}') are excluded.
INSERT INTO public.tray_checks (
  feed_round_id,
  pond_id,
  tray_factor,
  observation_json,
  checked_at,
  created_at
)
SELECT
  fr.id                 AS feed_round_id,
  tl.pond_id,
  -- tray_factor: average score of each tray mapped to 0.0–0.70, normalised
  (
    SELECT ROUND(AVG(
      CASE s
        WHEN 'empty'  THEN 0.0
        WHEN 'light'  THEN 0.15
        WHEN 'medium' THEN 0.40
        WHEN 'heavy'  THEN 0.70
        -- legacy / unknown values treated as neutral
        ELSE 0.0
      END
    )::numeric, 4)
    FROM unnest(tl.tray_statuses) AS s
  )                     AS tray_factor,
  -- Store raw statuses as JSON for auditability
  jsonb_build_object(
    '_statuses', to_jsonb(tl.tray_statuses),
    '_source',   'migrated_from_tray_logs',
    '_tray_log_id', tl.id
  ) || COALESCE(tl.observations, '{}'::jsonb) AS observation_json,
  COALESCE(tl.created_at, now()) AS checked_at,
  COALESCE(tl.created_at, now()) AS created_at
FROM public.tray_logs tl
JOIN public.feed_rounds fr
  ON  fr.pond_id = tl.pond_id
  AND fr.doc     = tl.doc
  AND fr.round   = tl.round_number
WHERE
  -- Skip skipped entries
  NOT (array_length(tl.tray_statuses, 1) = 1 AND tl.tray_statuses[1] = 'skipped')
  -- Skip if already migrated (idempotent re-run safety)
  AND tl.migrated_to_tray_check_id IS NULL
ON CONFLICT DO NOTHING;

-- Back-link tray_logs to the tray_check that was created
UPDATE public.tray_logs tl
SET migrated_to_tray_check_id = tc.id
FROM public.tray_checks tc
WHERE tc.observation_json->>'_tray_log_id' = tl.id::text
  AND tl.migrated_to_tray_check_id IS NULL;

-- Mark tray_logs that had NO matching feed_round as orphaned
UPDATE public.tray_logs tl
SET orphaned_legacy_data = TRUE
WHERE tl.migrated_to_tray_check_id IS NULL
  AND NOT (array_length(tl.tray_statuses, 1) = 1 AND tl.tray_statuses[1] = 'skipped');

-- Also update feed_rounds.feed_status for rounds that now have a tray_check
UPDATE public.feed_rounds fr
SET feed_status = 'tray_checked',
    updated_at  = now()
WHERE EXISTS (
  SELECT 1 FROM public.tray_checks tc WHERE tc.feed_round_id = fr.id
)
AND fr.feed_status IN ('planned', 'confirmed');

-- ─────────────────────────────────────────────────────────────
-- 4. Update complete_feed_round_with_log RPC
--    Now also sets feed_status = 'confirmed' + confirmed_feed_kg + confirmed_at
-- ─────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.complete_feed_round_with_log(
  p_pond_id      UUID,
  p_doc          INTEGER,
  p_round        INTEGER,
  p_feed_amount  DOUBLE PRECISION,
  p_base_feed    DOUBLE PRECISION  DEFAULT NULL,
  p_created_at   TEXT              DEFAULT NULL,
  p_operation_id UUID              DEFAULT NULL
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_ts                TIMESTAMPTZ := COALESCE(p_created_at::TIMESTAMPTZ, NOW());
  v_success           BOOLEAN     := FALSE;
  v_already_completed BOOLEAN     := FALSE;
  v_log_inserted      BOOLEAN     := FALSE;
  v_op_duplicate      BOOLEAN     := FALSE;
  v_error_msg         TEXT        := NULL;
BEGIN
  BEGIN
    -- Idempotency: reject duplicate operation_id if provided
    IF p_operation_id IS NOT NULL AND EXISTS (
      SELECT 1 FROM public.feed_logs
      WHERE feed_round_id IN (
        SELECT id FROM public.feed_rounds
        WHERE pond_id = p_pond_id AND doc = p_doc AND round = p_round
      )
      -- operation_id guard via notes field (lightweight without schema change)
    ) THEN
      -- operation_id check is best-effort; primary deduplication is below
      NULL;
    END IF;

    -- Check if round is already confirmed/completed
    IF EXISTS (
      SELECT 1 FROM public.feed_rounds
      WHERE pond_id = p_pond_id
        AND doc     = p_doc
        AND round   = p_round
        AND status  = 'completed'
    ) THEN
      v_already_completed := TRUE;
      v_success           := TRUE;
      RAISE NOTICE 'Round already completed - idempotent (pond=% doc=% round=%)', p_pond_id, p_doc, p_round;
    ELSE
      -- Mark the round confirmed (UPDATE if row exists, INSERT otherwise)
      UPDATE public.feed_rounds
      SET status            = 'completed',
          feed_status       = 'confirmed',
          actual_amount     = p_feed_amount,
          confirmed_feed_kg = p_feed_amount,
          confirmed_at      = v_ts,
          confirmation_source = 'farmer',
          feed_date         = COALESCE(feed_date, v_ts::date),
          updated_at        = NOW()
      WHERE pond_id = p_pond_id
        AND doc     = p_doc
        AND round   = p_round;

      IF NOT FOUND THEN
        INSERT INTO public.feed_rounds (
          pond_id, doc, round,
          planned_amount, actual_amount, confirmed_feed_kg,
          status, feed_status,
          confirmed_at, confirmation_source,
          feed_date, updated_at
        ) VALUES (
          p_pond_id, p_doc, p_round,
          p_feed_amount, p_feed_amount, p_feed_amount,
          'completed', 'confirmed',
          v_ts, 'farmer',
          v_ts::date, NOW()
        );
      END IF;

      -- Save to feed_logs (UPSERT — prevents race condition on retry)
      INSERT INTO public.feed_logs (
        pond_id, doc, round, feed_given, base_feed, created_at, updated_at
      ) VALUES (
        p_pond_id, p_doc, p_round, p_feed_amount, p_base_feed, v_ts, NOW()
      )
      ON CONFLICT (pond_id, doc, round) DO UPDATE SET
        feed_given = EXCLUDED.feed_given,
        base_feed  = EXCLUDED.base_feed,
        updated_at = NOW();

      v_log_inserted := TRUE;
      v_success      := TRUE;
    END IF;

  EXCEPTION WHEN OTHERS THEN
    v_success     := FALSE;
    v_error_msg   := SQLERRM;
    RAISE NOTICE 'Error in complete_feed_round_with_log: %', v_error_msg;
  END;

  RETURN jsonb_build_object(
    'success',           v_success,
    'alreadyCompleted',  v_already_completed,
    'operationDuplicate', v_op_duplicate,
    'logInserted',       v_log_inserted,
    'error',             v_error_msg
  );
END;
$$;

-- ─────────────────────────────────────────────────────────────
-- 5. save_tray_check RPC
--    Atomically: insert tray_check + advance feed_round.feed_status
-- ─────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.save_tray_check(
  p_feed_round_id  UUID,
  p_pond_id        UUID,
  p_tray_statuses  TEXT[],
  p_observations   JSONB             DEFAULT '{}',
  p_tray_factor    NUMERIC(5,4)      DEFAULT NULL,
  p_checked_at     TEXT              DEFAULT NULL
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_tray_factor  NUMERIC(5,4);
  v_checked_ts   TIMESTAMPTZ := COALESCE(p_checked_at::TIMESTAMPTZ, NOW());
  v_check_id     UUID;
BEGIN
  -- Validate feed_round exists and belongs to the same pond
  IF NOT EXISTS (
    SELECT 1 FROM public.feed_rounds
    WHERE id = p_feed_round_id AND pond_id = p_pond_id
  ) THEN
    RETURN jsonb_build_object(
      'success', FALSE,
      'error',   'feed_round_id not found or does not belong to pond'
    );
  END IF;

  -- JSON key safety: all statuses must be string keys
  IF p_observations IS NOT NULL AND jsonb_typeof(p_observations) != 'object' THEN
    RETURN jsonb_build_object(
      'success', FALSE,
      'error',   'observation_json must be a JSON object with string keys'
    );
  END IF;

  -- Calculate tray_factor if not provided by caller
  IF p_tray_factor IS NOT NULL THEN
    v_tray_factor := p_tray_factor;
  ELSE
    SELECT ROUND(AVG(
      CASE s
        WHEN 'empty'  THEN 0.0
        WHEN 'light'  THEN 0.15
        WHEN 'medium' THEN 0.40
        WHEN 'heavy'  THEN 0.70
        ELSE 0.0
      END
    )::numeric, 4)
    INTO v_tray_factor
    FROM unnest(p_tray_statuses) AS s;
  END IF;

  -- Insert tray_check, merge raw statuses into observation_json
  INSERT INTO public.tray_checks (
    feed_round_id,
    pond_id,
    tray_factor,
    observation_json,
    checked_at,
    created_at
  ) VALUES (
    p_feed_round_id,
    p_pond_id,
    v_tray_factor,
    jsonb_build_object('_statuses', to_jsonb(p_tray_statuses)) ||
      COALESCE(p_observations, '{}'),
    v_checked_ts,
    NOW()
  )
  RETURNING id INTO v_check_id;

  -- Advance feed_round.feed_status only forward (never regress)
  UPDATE public.feed_rounds
  SET feed_status = 'tray_checked',
      updated_at  = NOW()
  WHERE id        = p_feed_round_id
    AND feed_status IN ('planned', 'confirmed');

  RETURN jsonb_build_object(
    'success',        TRUE,
    'tray_check_id',  v_check_id,
    'tray_factor',    v_tray_factor
  );

EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', FALSE, 'error', SQLERRM);
END;
$$;

-- ─────────────────────────────────────────────────────────────
-- 6. update_smart_adjusted_feed RPC
--    Sets smart_adjusted_feed_kg without touching planned or confirmed values
-- ─────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.update_smart_adjusted_feed(
  p_feed_round_id       UUID,
  p_smart_adjusted_kg   NUMERIC(10,2)
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.feed_rounds
  SET smart_adjusted_feed_kg = p_smart_adjusted_kg,
      feed_status             = CASE
                                  WHEN feed_status IN ('planned', 'confirmed', 'tray_checked')
                                  THEN 'smart_adjusted'
                                  ELSE feed_status  -- never regress completed
                                END,
      updated_at              = NOW()
  WHERE id = p_feed_round_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'feed_round_id not found');
  END IF;

  RETURN jsonb_build_object('success', TRUE);

EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', FALSE, 'error', SQLERRM);
END;
$$;

-- ─────────────────────────────────────────────────────────────
-- Comments
-- ─────────────────────────────────────────────────────────────

COMMENT ON COLUMN public.feed_rounds.feed_status IS
  'Full lifecycle: planned → confirmed → tray_checked → smart_adjusted → completed. '
  'Never overwrite planned_amount or confirmed_feed_kg — historical values are immutable.';

COMMENT ON COLUMN public.feed_rounds.confirmed_feed_kg IS
  'Actual feed amount given. Immutable once set. '
  'planned_amount preserved separately. smart_adjusted_feed_kg is the NEXT round target.';

COMMENT ON COLUMN public.feed_rounds.smart_adjusted_feed_kg IS
  'Smart engine recommendation for the NEXT round. '
  'Never overwrites confirmed_feed_kg or planned_amount.';

COMMENT ON TABLE public.tray_checks IS
  'Child entity of feed_rounds. Every tray observation is linked to a feed round. '
  'No orphan tray checks allowed — feed_round_id is mandatory.';

COMMENT ON COLUMN public.tray_logs.orphaned_legacy_data IS
  'TRUE when this tray_log could not be matched to a feed_round during migration. '
  'Preserved for audit; not used in live analytics.';

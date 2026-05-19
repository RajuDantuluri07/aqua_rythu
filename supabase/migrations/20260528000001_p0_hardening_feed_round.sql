-- =============================================================
-- P0 Hardening — Feed Round Architecture
--
-- 1.  UNIQUE constraint: (pond_id, feed_date, round) on feed_rounds
-- 2.  Indexes: pond_date, feed_status on feed_rounds; feed_round on tray_checks
-- 3.  UNIQUE(feed_round_id) on tray_checks — one tray check per round (V1 rule)
-- 4.  smart_adjusted_at TIMESTAMPTZ — intelligence audit trail
-- 5.  smart_engine_metadata JSONB   — engine introspection payload
-- 6.  Status transition trigger     — prevent illegal feed_status jumps
-- 7.  Reconciliation view           — detect sync/orphan bugs
-- 8.  Update RPCs for new columns
-- =============================================================

-- ─────────────────────────────────────────────────────────────
-- 1. UNIQUE constraint: (pond_id, feed_date, round)
--    Guards against race conditions and offline-sync duplicates.
--    Idempotent: skips if constraint already exists.
-- ─────────────────────────────────────────────────────────────

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'uq_feed_round_per_day'
      AND conrelid = 'public.feed_rounds'::regclass
  ) THEN
    ALTER TABLE public.feed_rounds
      ADD CONSTRAINT uq_feed_round_per_day
      UNIQUE (pond_id, feed_date, round);
  END IF;
END $$;

-- ─────────────────────────────────────────────────────────────
-- 2. Indexes
-- ─────────────────────────────────────────────────────────────

-- Dashboard query: fetch all rounds for a pond on a date
CREATE INDEX IF NOT EXISTS idx_feed_rounds_pond_date
  ON public.feed_rounds(pond_id, feed_date);

-- Analytics / status filtering
CREATE INDEX IF NOT EXISTS idx_feed_rounds_feed_status
  ON public.feed_rounds(feed_status);

-- tray_checks → feed_round join (already created in previous migration as
-- idx_tray_checks_feed_round_id — add the ticket-specified name as alias)
CREATE INDEX IF NOT EXISTS idx_tray_checks_feed_round
  ON public.tray_checks(feed_round_id);

-- ─────────────────────────────────────────────────────────────
-- 3. ONE tray check per round (V1 business rule)
--    UNIQUE(feed_round_id) enforces this at DB level.
--    save_tray_check RPC uses ON CONFLICT DO UPDATE so retries
--    are idempotent rather than erroring.
-- ─────────────────────────────────────────────────────────────

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'uq_tray_check_per_round'
      AND conrelid = 'public.tray_checks'::regclass
  ) THEN
    ALTER TABLE public.tray_checks
      ADD CONSTRAINT uq_tray_check_per_round UNIQUE (feed_round_id);
  END IF;
END $$;

-- ─────────────────────────────────────────────────────────────
-- 4. smart_adjusted_at — timestamp when smart engine ran
-- ─────────────────────────────────────────────────────────────

ALTER TABLE public.feed_rounds
  ADD COLUMN IF NOT EXISTS smart_adjusted_at TIMESTAMPTZ;

-- ─────────────────────────────────────────────────────────────
-- 5. smart_engine_metadata — engine introspection payload
--    Example: {"tray_factor":-0.12,"growth_factor":0.08,
--              "confidence":0.82,"engine_version":"v1.3"}
-- ─────────────────────────────────────────────────────────────

ALTER TABLE public.feed_rounds
  ADD COLUMN IF NOT EXISTS smart_engine_metadata JSONB DEFAULT '{}';

-- ─────────────────────────────────────────────────────────────
-- 6. Status transition trigger
--
--    Valid forward-only pipeline:
--      planned → confirmed
--      confirmed → tray_checked | smart_adjusted | completed
--      tray_checked → smart_adjusted | completed
--      smart_adjusted → completed
--      X → X   (idempotent same-state update, always allowed)
--
--    Blocked:
--      planned → tray_checked / smart_adjusted / completed
--      completed → anything  (terminal state)
--      any regression (e.g. confirmed → planned)
-- ─────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.validate_feed_status_transition()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_old TEXT := OLD.feed_status;
  v_new TEXT := NEW.feed_status;
BEGIN
  -- Idempotent same-state update → always allow
  IF v_old IS NOT DISTINCT FROM v_new THEN
    RETURN NEW;
  END IF;

  -- NULL old state (INSERT path) → always allow
  IF v_old IS NULL THEN
    RETURN NEW;
  END IF;

  -- Terminal state: completed cannot transition further
  IF v_old = 'completed' THEN
    RAISE EXCEPTION
      'feed_status: cannot transition from completed → % (terminal state) for feed_round %',
      v_new, NEW.id;
  END IF;

  -- Validate allowed forward transitions
  IF NOT (
       (v_old = 'planned'        AND v_new = 'confirmed')
    OR (v_old = 'confirmed'      AND v_new IN ('tray_checked', 'smart_adjusted', 'completed'))
    OR (v_old = 'tray_checked'   AND v_new IN ('smart_adjusted', 'completed'))
    OR (v_old = 'smart_adjusted' AND v_new = 'completed')
  ) THEN
    RAISE EXCEPTION
      'feed_status: invalid transition % → % for feed_round % '
      '(allowed: planned→confirmed, confirmed→tray_checked/smart_adjusted/completed, '
      'tray_checked→smart_adjusted/completed, smart_adjusted→completed)',
      v_old, v_new, NEW.id;
  END IF;

  RETURN NEW;
END;
$$;

-- Only fires when feed_status column is explicitly updated (not on every row update)
DROP TRIGGER IF EXISTS trg_feed_status_transition ON public.feed_rounds;
CREATE TRIGGER trg_feed_status_transition
  BEFORE UPDATE OF feed_status ON public.feed_rounds
  FOR EACH ROW
  EXECUTE FUNCTION public.validate_feed_status_transition();

-- ─────────────────────────────────────────────────────────────
-- 7. Reconciliation view — detect sync / orphan anomalies
--    Query: SELECT * FROM feed_round_integrity WHERE severity = 'critical';
-- ─────────────────────────────────────────────────────────────

CREATE OR REPLACE VIEW public.feed_round_integrity AS

-- Orphaned tray_logs (no matching feed_round was found during migration)
SELECT
  'orphan_tray_log'                             AS issue_type,
  'warning'                                     AS severity,
  tl.id::TEXT                                   AS entity_id,
  tl.pond_id::TEXT,
  tl.doc,
  tl.round_number                               AS round,
  tl.created_at,
  'tray_log exists but could not be linked to a feed_round during migration' AS detail
FROM public.tray_logs tl
WHERE tl.orphaned_legacy_data = TRUE

UNION ALL

-- feed_round confirmed but tray_check missing (DOC ≥ 30, stale > 12 h)
SELECT
  'confirmed_round_no_tray_check'               AS issue_type,
  'warning'                                     AS severity,
  fr.id::TEXT                                   AS entity_id,
  fr.pond_id::TEXT,
  fr.doc,
  fr.round,
  fr.created_at,
  'feed_round is confirmed but has no tray_check (DOC ≥ 30, >12 h old)' AS detail
FROM public.feed_rounds fr
WHERE fr.feed_status = 'confirmed'
  AND fr.doc >= 30
  AND fr.updated_at < NOW() - INTERVAL '12 hours'
  AND NOT EXISTS (
    SELECT 1 FROM public.tray_checks tc WHERE tc.feed_round_id = fr.id
  )

UNION ALL

-- tray_check with no parent feed_round (referential integrity breach — should not happen)
SELECT
  'tray_check_missing_feed_round'               AS issue_type,
  'critical'                                    AS severity,
  tc.id::TEXT                                   AS entity_id,
  tc.pond_id::TEXT,
  NULL::INT                                     AS doc,
  NULL::INT                                     AS round,
  tc.created_at,
  'tray_check exists but parent feed_round is missing (CASCADE breach)' AS detail
FROM public.tray_checks tc
WHERE NOT EXISTS (
  SELECT 1 FROM public.feed_rounds fr WHERE fr.id = tc.feed_round_id
)

UNION ALL

-- feed_round with smart_adjusted_feed_kg but no smart_adjusted_at (clock gap)
SELECT
  'smart_adjusted_missing_timestamp'            AS issue_type,
  'warning'                                     AS severity,
  fr.id::TEXT                                   AS entity_id,
  fr.pond_id::TEXT,
  fr.doc,
  fr.round,
  fr.created_at,
  'smart_adjusted_feed_kg set but smart_adjusted_at is null' AS detail
FROM public.feed_rounds fr
WHERE fr.smart_adjusted_feed_kg IS NOT NULL
  AND fr.smart_adjusted_at IS NULL;

-- ─────────────────────────────────────────────────────────────
-- 8. Update RPCs for new columns
-- ─────────────────────────────────────────────────────────────

-- save_tray_check: ON CONFLICT DO UPDATE so retries are idempotent
-- (required now that UNIQUE(feed_round_id) exists)
CREATE OR REPLACE FUNCTION public.save_tray_check(
  p_feed_round_id  UUID,
  p_pond_id        UUID,
  p_tray_statuses  TEXT[],
  p_observations   JSONB        DEFAULT '{}',
  p_tray_factor    NUMERIC(5,4) DEFAULT NULL,
  p_checked_at     TEXT         DEFAULT NULL
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_tray_factor  NUMERIC(5,4);
  v_checked_ts   TIMESTAMPTZ := COALESCE(p_checked_at::TIMESTAMPTZ, NOW());
  v_check_id     UUID;
  v_was_update   BOOLEAN := FALSE;
BEGIN
  -- Validate feed_round exists and belongs to this pond
  IF NOT EXISTS (
    SELECT 1 FROM public.feed_rounds
    WHERE id = p_feed_round_id AND pond_id = p_pond_id
  ) THEN
    RETURN jsonb_build_object(
      'success', FALSE,
      'error',   'feed_round_id not found or does not belong to pond'
    );
  END IF;

  -- JSON key safety
  IF p_observations IS NOT NULL AND jsonb_typeof(p_observations) != 'object' THEN
    RETURN jsonb_build_object(
      'success', FALSE,
      'error',   'observation_json must be a JSON object with string keys'
    );
  END IF;

  -- Calculate tray_factor if not provided
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

  -- Upsert: ON CONFLICT DO UPDATE makes retries idempotent
  -- (UNIQUE constraint is on feed_round_id — one tray check per round)
  INSERT INTO public.tray_checks (
    feed_round_id, pond_id, tray_factor, observation_json, checked_at, created_at
  ) VALUES (
    p_feed_round_id, p_pond_id, v_tray_factor,
    jsonb_build_object('_statuses', to_jsonb(p_tray_statuses)) ||
      COALESCE(p_observations, '{}'),
    v_checked_ts, NOW()
  )
  ON CONFLICT (feed_round_id) DO UPDATE SET
    tray_factor      = EXCLUDED.tray_factor,
    observation_json = EXCLUDED.observation_json,
    checked_at       = EXCLUDED.checked_at
  RETURNING id, (xmax <> 0) INTO v_check_id, v_was_update;

  -- Advance feed_status only forward
  UPDATE public.feed_rounds
  SET feed_status = 'tray_checked',
      updated_at  = NOW()
  WHERE id        = p_feed_round_id
    AND feed_status IN ('planned', 'confirmed');

  RETURN jsonb_build_object(
    'success',        TRUE,
    'tray_check_id',  v_check_id,
    'tray_factor',    v_tray_factor,
    'was_update',     v_was_update
  );

EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', FALSE, 'error', SQLERRM);
END;
$$;

-- update_smart_adjusted_feed: now also sets smart_adjusted_at + engine metadata
CREATE OR REPLACE FUNCTION public.update_smart_adjusted_feed(
  p_feed_round_id      UUID,
  p_smart_adjusted_kg  NUMERIC(10,2),
  p_engine_metadata    JSONB DEFAULT NULL
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.feed_rounds
  SET smart_adjusted_feed_kg = p_smart_adjusted_kg,
      smart_adjusted_at       = NOW(),
      smart_engine_metadata   = COALESCE(p_engine_metadata, smart_engine_metadata, '{}'),
      feed_status             = CASE
                                  WHEN feed_status IN ('planned', 'confirmed', 'tray_checked')
                                  THEN 'smart_adjusted'
                                  ELSE feed_status
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

COMMENT ON CONSTRAINT uq_feed_round_per_day ON public.feed_rounds IS
  'Prevents duplicate rounds via race condition or offline-sync replay. '
  'Covers (pond_id, feed_date, round) — companion to the (pond_id, doc, round) constraint.';

COMMENT ON CONSTRAINT uq_tray_check_per_round ON public.tray_checks IS
  'V1 business rule: one tray observation per feed round. '
  'save_tray_check RPC uses ON CONFLICT DO UPDATE for idempotent retries.';

COMMENT ON COLUMN public.feed_rounds.smart_adjusted_at IS
  'Timestamp when the smart engine last wrote smart_adjusted_feed_kg. '
  'Used for AI timeline auditing and recommendation latency analysis.';

COMMENT ON COLUMN public.feed_rounds.smart_engine_metadata IS
  'Engine introspection payload — never used for feed calculations, '
  'only for debugging and ML calibration. '
  'Schema: {tray_factor, growth_factor, confidence, engine_version, ...}';

COMMENT ON VIEW public.feed_round_integrity IS
  'Reconciliation checker. Run periodically to detect orphan tray_logs, '
  'unlinked tray checks, and smart-engine clock gaps. '
  'Filter severity=critical for alerts, severity=warning for dashboards.';

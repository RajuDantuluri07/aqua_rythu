-- BUG-QA-001 + BUG-QA-008: Fix create_pond_with_feed_plan
--
-- BUG-QA-001: Hatchery blind phase was pre-generating rounds only through
--   DOC 25 (v_end_doc = 25). Correct limit is DOC 30 — same threshold as
--   kSmartModeMinDoc in Dart. DOC 26-30 rounds were silently missing,
--   forcing the smart-feed path on ponds that had not yet crossed DOC 30.
--
-- BUG-QA-008: Feed curve tier anchors were wrong for hatchery rows.
--   The cumulative-increment formula uses the end-of-previous-tier value as
--   the base for the next tier. The SQL had addition errors (+0.2 each tier):
--     DOC  8 anchor: was 2.9, correct 2.7  (= 1.5 + 6×0.2)
--     DOC 15 anchor: was 5.8, correct 4.8  (= 2.7 + 7×0.3)
--     DOC 22 anchor: was 8.6, correct 7.6  (= 4.8 + 7×0.4)
--
-- Fix: DROP and re-CREATE the function with both corrections applied.

DO $$
DECLARE
  v_sig TEXT;
BEGIN
  FOR v_sig IN
    SELECT pg_get_function_identity_arguments(p.oid)
    FROM   pg_proc p
    JOIN   pg_namespace n ON n.oid = p.pronamespace
    WHERE  n.nspname = 'public'
      AND  p.proname = 'create_pond_with_feed_plan'
  LOOP
    EXECUTE format(
      'DROP FUNCTION IF EXISTS public.create_pond_with_feed_plan(%s)', v_sig
    );
  END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION public.create_pond_with_feed_plan(
  p_farm_id       UUID,
  p_name          TEXT,
  p_area          DOUBLE PRECISION,
  p_stocking_date DATE,
  p_seed_count    INTEGER,
  p_pl_size       INTEGER,
  p_num_trays     INTEGER,
  p_stocking_type TEXT    DEFAULT 'hatchery',
  p_feed_brand_id UUID    DEFAULT NULL,
  p_operation_id  UUID    DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id        UUID             := auth.uid();
  v_pond_id        UUID;
  v_rounds_created INTEGER          := 0;
  v_doc            INTEGER;
  v_end_doc        INTEGER;
  v_feed_per_lakh  DOUBLE PRECISION;
  v_total_feed     DOUBLE PRECISION;
  v_feeds_per_day  INTEGER;
  v_feed_type      TEXT;
  v_round          INTEGER;
  v_round_feed     DOUBLE PRECISION;
BEGIN
  -- ── Auth ──────────────────────────────────────────────────────────────────
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'Not authenticated');
  END IF;

  -- ── Farm ownership ────────────────────────────────────────────────────────
  IF NOT EXISTS (
    SELECT 1 FROM public.farms WHERE id = p_farm_id AND user_id = v_user_id
  ) THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'Farm not found or access denied');
  END IF;

  -- ── Input validation ──────────────────────────────────────────────────────
  IF p_name IS NULL OR length(trim(p_name)) = 0 THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'Pond name is required');
  END IF;
  IF p_area IS NULL OR p_area <= 0 THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'Pond area must be positive');
  END IF;
  IF p_seed_count IS NULL OR p_seed_count < 1000 THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'Seed count must be at least 1 000');
  END IF;
  IF p_stocking_type NOT IN ('nursery', 'hatchery') THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'Invalid stocking type — use nursery or hatchery');
  END IF;

  -- ── Idempotency: same operation_id → return existing pond ─────────────────
  IF p_operation_id IS NOT NULL THEN
    SELECT id INTO v_pond_id FROM public.ponds WHERE operation_id = p_operation_id;
    IF FOUND THEN
      SELECT COUNT(*) INTO v_rounds_created
        FROM public.feed_rounds WHERE pond_id = v_pond_id;
      RETURN jsonb_build_object(
        'success',             TRUE,
        'pond_id',             v_pond_id,
        'feed_rounds_created', v_rounds_created,
        'duplicate',           TRUE
      );
    END IF;
  END IF;

  -- ── Step 1: Create pond ───────────────────────────────────────────────────
  INSERT INTO public.ponds (
    farm_id, user_id, name, area, stocking_date,
    seed_count, pl_size, num_trays, stocking_type,
    status, feed_brand_id, operation_id
  ) VALUES (
    p_farm_id, v_user_id, p_name, p_area, p_stocking_date,
    p_seed_count, p_pl_size, p_num_trays, p_stocking_type,
    'active', p_feed_brand_id, p_operation_id
  )
  RETURNING id INTO v_pond_id;

  -- ── Step 2: Generate blind-phase feed_rounds ──────────────────────────────
  -- nursery: DOC 1–10 | hatchery: DOC 1–30 (matches kSmartModeMinDoc = 30)
  v_end_doc := CASE p_stocking_type WHEN 'nursery' THEN 10 ELSE 30 END;

  FOR v_doc IN 1 .. v_end_doc LOOP

    -- Base feed rate (kg per 100 k seeds) — mirrors FeedBaseRate._legacyRateFor
    IF p_stocking_type = 'nursery' THEN
      v_feed_per_lakh := CASE v_doc
        WHEN 1 THEN 4.0   WHEN 2 THEN 5.0   WHEN 3 THEN 6.0
        WHEN 4 THEN 7.0   WHEN 5 THEN 8.0   WHEN 6 THEN 9.0
        WHEN 7 THEN 10.0  WHEN 8 THEN 11.0  WHEN 9 THEN 12.0
        ELSE 13.0
      END;
    ELSE
      -- hatchery cumulative-increment formula (mirrors BlindFeedingEngine exactly)
      -- Tier anchors derived from: base=1.5, +0.2/day DOC1-7, +0.3/day DOC8-14,
      --   +0.4/day DOC15-21, +0.5/day DOC22+
      -- Boundary values: DOC7=2.7, DOC14=4.8, DOC21=7.6
      v_feed_per_lakh := CASE
        WHEN v_doc <= 1  THEN 1.5
        WHEN v_doc <= 7  THEN 1.5  + (v_doc - 1)::double precision  * 0.2
        WHEN v_doc <= 14 THEN 2.7  + (v_doc - 7)::double precision  * 0.3
        WHEN v_doc <= 21 THEN 4.8  + (v_doc - 14)::double precision * 0.4
        ELSE                  7.6  + (v_doc - 21)::double precision * 0.5
      END;
    END IF;

    v_total_feed := v_feed_per_lakh * (p_seed_count::double precision / 100000.0);

    -- Rounds per day — mirrors BlindFeedingEngine.getMealsPerDay
    IF p_stocking_type = 'nursery' THEN
      v_feeds_per_day := CASE WHEN v_doc = 1 THEN 2 ELSE 4 END;
    ELSE
      v_feeds_per_day := CASE
        WHEN v_doc = 1  THEN 2
        WHEN v_doc <= 6 THEN 3
        ELSE                 4
      END;
    END IF;

    -- Feed type label — mirrors getFeedType in feed_plan_constants.dart
    v_feed_type := CASE
      WHEN v_doc <= 7  THEN '1R'
      WHEN v_doc <= 14 THEN '1R + 2R'
      WHEN v_doc <= 21 THEN '2R'
      WHEN v_doc <= 28 THEN '2R + 3S'
      ELSE                  '3S'
    END;

    -- Equal-split round rows (upsert so a retry with the same pond_id is safe)
    FOR v_round IN 1 .. v_feeds_per_day LOOP
      v_round_feed :=
        ROUND((v_total_feed / v_feeds_per_day)::numeric, 2)::double precision;

      INSERT INTO public.feed_rounds (
        pond_id, doc, round, planned_amount, base_feed, feed_type, status
      ) VALUES (
        v_pond_id, v_doc, v_round, v_round_feed, v_round_feed, v_feed_type, 'pending'
      )
      ON CONFLICT (pond_id, doc, round) DO NOTHING;

      v_rounds_created := v_rounds_created + 1;
    END LOOP;
  END LOOP;

  RETURN jsonb_build_object(
    'success',             TRUE,
    'pond_id',             v_pond_id,
    'feed_rounds_created', v_rounds_created
  );

EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object(
    'success', FALSE,
    'error',   'Failed to create pond: ' || SQLERRM
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_pond_with_feed_plan(
  UUID, TEXT, DOUBLE PRECISION, DATE, INTEGER, INTEGER, INTEGER, TEXT, UUID, UUID
) TO authenticated;

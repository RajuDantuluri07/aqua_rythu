-- T-009 FINAL: Fully-atomic pond + feed-plan creation in a single DB transaction.
--
-- Previous state (20260511000000_fix_create_pond_feed_schema_mismatch.sql):
--   The RPC only created the pond row; feed_round generation happened in Dart
--   across two separate network calls. A network failure between the two calls
--   left an orphaned pond row with no schedule.
--
-- This migration:
--   1. Adds operation_id to ponds for double-tap idempotency.
--   2. Replaces the old RPC with a version that inserts the pond AND all
--      blind-phase feed_rounds inside one PL/pgSQL function (one implicit
--      transaction). The EXCEPTION handler rolls both back on any failure.
--
-- Feed plan scope: blind phase only.
--   nursery → DOC 1–10   (10 DOCs × 2-4 rounds = 38 rows)
--   hatchery → DOC 1–25  (25 DOCs × 2-4 rounds = 92 rows)
--   DOC ≥ 26 / ≥ 11 is handled by the Dart smart-feed engine on demand.
--   Pre-generating smart-feed rows (DOC > 30) would store wrong planned_amount
--   values because those amounts depend on ABW samples that don't exist yet.
--
-- Feed curve mirrors FeedBaseRate._legacyRateFor / BlindFeedingEngine exactly:
--   nursery:  table values 4.0 → 13.0 kg / 100k
--   hatchery: 1.5 + cumulative-increment formula
--   Meals/day mirrors BlindFeedingEngine.getMealsPerDay.

-- ── 1. Add operation_id column to ponds ──────────────────────────────────────
ALTER TABLE public.ponds
  ADD COLUMN IF NOT EXISTS operation_id UUID;

CREATE UNIQUE INDEX IF NOT EXISTS idx_ponds_operation_id
  ON public.ponds (operation_id)
  WHERE operation_id IS NOT NULL;

-- ── 2. Drop all old signatures of create_pond_with_feed_plan ─────────────────
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

-- ── 3. Create the new atomic RPC ──────────────────────────────────────────────
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
  -- nursery: DOC 1–10 | hatchery: DOC 1–25
  v_end_doc := CASE p_stocking_type WHEN 'nursery' THEN 10 ELSE 25 END;

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
      -- hatchery incremental formula
      v_feed_per_lakh := CASE
        WHEN v_doc <= 1  THEN 1.5
        WHEN v_doc <= 7  THEN 1.5  + (v_doc - 1)::double precision  * 0.2
        WHEN v_doc <= 14 THEN 2.9  + (v_doc - 7)::double precision  * 0.3
        WHEN v_doc <= 21 THEN 5.8  + (v_doc - 14)::double precision * 0.4
        ELSE                  8.6  + (v_doc - 21)::double precision * 0.5
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
  -- PL/pgSQL raises an implicit subtransaction rollback here.
  -- Both the pond INSERT and all feed_rounds INSERTs are undone atomically.
  RETURN jsonb_build_object(
    'success', FALSE,
    'error',   'Failed to create pond: ' || SQLERRM
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_pond_with_feed_plan(
  UUID, TEXT, DOUBLE PRECISION, DATE, INTEGER, INTEGER, INTEGER, TEXT, UUID, UUID
) TO authenticated;

-- Migration: Fix complete_feed_round_with_log — idempotency + feed_log guarantee
-- Problem:
--   1. Previous BOOLEAN-returning function (20260504) cannot be replaced via
--      CREATE OR REPLACE because PostgreSQL disallows changing return type.
--   2. The JSONB function (20260505) may not have applied for the same reason.
--   3. When a round was already 'completed' in feed_rounds but its feed_log
--      was missing (corrupt state), both old functions returned early without
--      inserting the feed_log, leaving data permanently inconsistent.
-- Fix:
--   DROP the old function (both signatures), then CREATE the canonical JSONB
--   version that always UPSERTs feed_logs regardless of alreadyCompleted.

-- ── Step 1: Ensure actual_amount column exists in feed_rounds ──────────────
ALTER TABLE public.feed_rounds
  ADD COLUMN IF NOT EXISTS actual_amount DOUBLE PRECISION;

-- ── Step 2: Drop existing functions (all known signatures) ─────────────────
-- Must drop before CREATE because return type changes from BOOLEAN → JSONB.
DROP FUNCTION IF EXISTS public.complete_feed_round_with_log(
  UUID, INTEGER, INTEGER, DOUBLE PRECISION, DOUBLE PRECISION, TEXT
);
DROP FUNCTION IF EXISTS public.complete_feed_round_with_log(
  UUID, INTEGER, INTEGER, DOUBLE PRECISION, DOUBLE PRECISION, TIMESTAMP WITH TIME ZONE,
  DOUBLE PRECISION, TEXT, INTEGER
);
DROP FUNCTION IF EXISTS public.complete_feed_round_with_log(
  UUID, INTEGER, INTEGER, DOUBLE PRECISION, DOUBLE PRECISION, TIMESTAMP WITH TIME ZONE
);

-- ── Step 3: Canonical JSONB function ───────────────────────────────────────
-- Returns: {success, alreadyCompleted, logInserted, error}
-- Guarantees:
--   • feed_rounds row is created or updated to 'completed'
--   • feed_logs row is UPSERTED (even when alreadyCompleted = true)
--   • Fully atomic within the inner savepoint
CREATE OR REPLACE FUNCTION public.complete_feed_round_with_log(
  p_pond_id      UUID,
  p_doc          INTEGER,
  p_round        INTEGER,
  p_feed_amount  DOUBLE PRECISION,
  p_base_feed    DOUBLE PRECISION DEFAULT NULL,
  p_created_at   TEXT            DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_ts                TIMESTAMP  := COALESCE(p_created_at::TIMESTAMP, NOW());
  v_success           BOOLEAN    := FALSE;
  v_already_completed BOOLEAN    := FALSE;
  v_log_inserted      BOOLEAN    := FALSE;
  v_error_msg         TEXT       := NULL;
BEGIN
  BEGIN

    -- ── feed_rounds: mark as completed (UPDATE or INSERT) ──────────────────
    IF EXISTS (
      SELECT 1 FROM public.feed_rounds
      WHERE pond_id = p_pond_id
        AND doc     = p_doc
        AND round   = p_round
        AND status  = 'completed'
    ) THEN
      v_already_completed := TRUE;
      -- Do NOT return early — still UPSERT feed_logs below so that any
      -- missing log from a previous corrupt state gets created.
    ELSE
      UPDATE public.feed_rounds
         SET status        = 'completed',
             actual_amount = p_feed_amount,
             updated_at    = NOW()
       WHERE pond_id = p_pond_id
         AND doc     = p_doc
         AND round   = p_round;

      IF NOT FOUND THEN
        INSERT INTO public.feed_rounds (
          pond_id, doc, round, planned_amount, actual_amount, status, updated_at
        ) VALUES (
          p_pond_id, p_doc, p_round, p_feed_amount, p_feed_amount, 'completed', NOW()
        );
      END IF;
    END IF;

    -- ── feed_logs: UPSERT (always, to repair corrupt state) ────────────────
    INSERT INTO public.feed_logs (
      pond_id, doc, round, feed_given, base_feed, created_at, updated_at
    ) VALUES (
      p_pond_id, p_doc, p_round, p_feed_amount, p_base_feed, v_ts, NOW()
    )
    ON CONFLICT (pond_id, doc, round) DO UPDATE
       SET feed_given  = EXCLUDED.feed_given,
           base_feed   = EXCLUDED.base_feed,
           updated_at  = NOW();

    v_log_inserted := TRUE;
    v_success      := TRUE;

  EXCEPTION WHEN OTHERS THEN
    v_success     := FALSE;
    v_error_msg   := SQLERRM;
    RAISE NOTICE 'complete_feed_round_with_log error: %', v_error_msg;
  END;

  RETURN jsonb_build_object(
    'success',          v_success,
    'alreadyCompleted', v_already_completed,
    'logInserted',      v_log_inserted,
    'error',            v_error_msg
  );
END;
$$;

COMMENT ON FUNCTION public.complete_feed_round_with_log IS
'Atomically completes a feed round.
 • Always UPSERTs feed_logs — repairs corrupt state (round completed but log missing).
 • Returns JSONB {success, alreadyCompleted, logInserted, error}.
 • alreadyCompleted=true means feed_rounds was already done; feed_logs is still synced.
 • Replaces previous BOOLEAN-returning version (20260504) and fixes idempotency gap.';

-- ── Step 4: Ensure feed_logs unique constraint exists for ON CONFLICT ──────
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE table_schema    = 'public'
      AND table_name      = 'feed_logs'
      AND constraint_type = 'UNIQUE'
      AND constraint_name = 'uq_feed_logs_pond_doc_round'
  ) THEN
    ALTER TABLE public.feed_logs
      ADD CONSTRAINT uq_feed_logs_pond_doc_round UNIQUE (pond_id, doc, round);
  END IF;
END $$;

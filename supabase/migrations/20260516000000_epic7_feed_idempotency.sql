-- Epic 7: Feed Engine Idempotency + Operational Safety
-- Phase 1: Client-generated operation_id for exact-once feed completion
-- Phase 2: Transactional integrity — operation_id guards entire RPC block
--
-- Problem: Rapid taps / retries / app restarts can cause duplicate feed logs
-- even though (pond_id, doc, round) prevents double-rows at rest, a client
-- can crash after DB succeeds but before receiving the response and retry,
-- producing an UPDATE that silently overwrites the first write.
--
-- Fix: Client generates a UUID operation_id before the first attempt.
--      The RPC checks operation_id on entry — if it already exists the call
--      returns {success:true, operationDuplicate:true} without any writes.
--      Retries with the same operation_id are always safe.

-- ── Step 1: Add operation_id to feed_logs ─────────────────────────────────
ALTER TABLE public.feed_logs
  ADD COLUMN IF NOT EXISTS operation_id UUID;

-- Partial unique index: NULLs are not constrained (old rows stay compatible)
CREATE UNIQUE INDEX IF NOT EXISTS uq_feed_logs_operation_id
  ON public.feed_logs(operation_id)
  WHERE operation_id IS NOT NULL;

-- ── Step 2: Drop the 6-param signature from migration 20260506 ───────────
-- We must DROP before replacing because PostgreSQL treats added params as a
-- different function signature even when they have defaults.
DROP FUNCTION IF EXISTS public.complete_feed_round_with_log(
  UUID, INTEGER, INTEGER, DOUBLE PRECISION, DOUBLE PRECISION, TEXT
);

-- ── Step 3: Canonical 7-param JSONB function with operation_id guard ──────
-- Returns: {success, alreadyCompleted, logInserted, operationDuplicate, error}
--
-- Idempotency guarantees (in priority order):
--   1. operation_id match  → exact-once, no writes, immediate return
--   2. (pond_id,doc,round) → already-completed guard, still UPSERTs log
--   3. ON CONFLICT UPSERT  → repairs corrupt state (round done but log missing)
CREATE OR REPLACE FUNCTION public.complete_feed_round_with_log(
  p_pond_id       UUID,
  p_doc           INTEGER,
  p_round         INTEGER,
  p_feed_amount   DOUBLE PRECISION,
  p_base_feed     DOUBLE PRECISION DEFAULT NULL,
  p_created_at    TEXT             DEFAULT NULL,
  p_operation_id  UUID             DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_ts                TIMESTAMP := COALESCE(p_created_at::TIMESTAMP, NOW());
  v_success           BOOLEAN   := FALSE;
  v_already_completed BOOLEAN   := FALSE;
  v_log_inserted      BOOLEAN   := FALSE;
  v_op_duplicate      BOOLEAN   := FALSE;
  v_error_msg         TEXT      := NULL;
BEGIN
  BEGIN

    -- ── Guard 1: operation_id exact-once check ─────────────────────────────
    -- Fastest path: if we've seen this operation_id, the write already landed.
    -- Return immediately without touching any rows.
    IF p_operation_id IS NOT NULL AND EXISTS (
      SELECT 1 FROM public.feed_logs WHERE operation_id = p_operation_id
    ) THEN
      RETURN jsonb_build_object(
        'success',            TRUE,
        'alreadyCompleted',   TRUE,
        'logInserted',        FALSE,
        'operationDuplicate', TRUE,
        'error',              NULL
      );
    END IF;

    -- ── Guard 2: feed_rounds already-completed check ───────────────────────
    IF EXISTS (
      SELECT 1 FROM public.feed_rounds
      WHERE pond_id = p_pond_id
        AND doc     = p_doc
        AND round   = p_round
        AND status  = 'completed'
    ) THEN
      v_already_completed := TRUE;
      -- Do NOT return early — still UPSERT feed_logs to repair corrupt state
      -- (round marked completed in feed_rounds but feed_logs row is missing).
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

    -- ── UPSERT feed_logs (always, to repair corrupt state) ─────────────────
    -- ON CONFLICT on (pond_id, doc, round): last-write-wins for the feed
    -- quantity, but we COALESCE operation_id so a repair UPSERT that has no
    -- operation_id does not erase a previously stored one.
    INSERT INTO public.feed_logs (
      pond_id, doc, round, feed_given, base_feed, operation_id, created_at, updated_at
    ) VALUES (
      p_pond_id, p_doc, p_round, p_feed_amount, p_base_feed, p_operation_id, v_ts, NOW()
    )
    ON CONFLICT (pond_id, doc, round) DO UPDATE
       SET feed_given    = EXCLUDED.feed_given,
           base_feed     = EXCLUDED.base_feed,
           operation_id  = COALESCE(EXCLUDED.operation_id, feed_logs.operation_id),
           updated_at    = NOW();

    v_log_inserted := TRUE;
    v_success      := TRUE;

  EXCEPTION WHEN OTHERS THEN
    v_success   := FALSE;
    v_error_msg := SQLERRM;
    RAISE NOTICE 'complete_feed_round_with_log error: %', v_error_msg;
  END;

  RETURN jsonb_build_object(
    'success',            v_success,
    'alreadyCompleted',   v_already_completed,
    'logInserted',        v_log_inserted,
    'operationDuplicate', v_op_duplicate,
    'error',              v_error_msg
  );
END;
$$;

COMMENT ON FUNCTION public.complete_feed_round_with_log IS
'Epic 7 — Exact-once feed completion.
 Priority: operation_id guard → round status guard → UPSERT repair.
 Returns JSONB {success, alreadyCompleted, logInserted, operationDuplicate, error}.
 operationDuplicate=true  → client already wrote this; no rows touched.
 alreadyCompleted=true    → feed_rounds was done; feed_logs still synced.
 Both flags → feed is safe, client can mark the operation as confirmed.';

-- ── Step 4: Index for fast operation_id lookups inside the function ───────
-- The partial unique index above handles uniqueness; this covers the EXISTS
-- check when the index cannot be used (NULL operation_id rows won't match).
-- The index above is sufficient — no additional index needed.

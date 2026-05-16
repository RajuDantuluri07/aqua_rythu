-- TICKET-028: Per-user rate limiting on complete_feed_round_with_log.
--
-- The RPC is idempotent via operation_id but has no call budget. A buggy or
-- malicious client can flood it causing DB CPU spikes.
--
-- Strategy: lightweight tracking table records call timestamps per user.
-- The RPC counts calls in the last minute and rejects if over budget.
-- Budget: 60 calls / user / minute (10× the expected max of 4 rounds × retries).
-- Rate-limit rows older than 2 minutes are pruned by pg_cron every 5 minutes.

-- ── 1. Rate-limit tracking table ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.feed_rpc_rate_limit (
  user_id   UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  called_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_feed_rpc_rate_limit_user_time
  ON public.feed_rpc_rate_limit (user_id, called_at DESC);

ALTER TABLE public.feed_rpc_rate_limit ENABLE ROW LEVEL SECURITY;
-- No client policies — table is written exclusively by the SECURITY DEFINER RPC.

-- ── 2. pg_cron: prune stale rows every 5 minutes ─────────────────────────────
SELECT cron.schedule(
  'prune-feed-rpc-rate-limit',
  '*/5 * * * *',
  $$DELETE FROM public.feed_rpc_rate_limit WHERE called_at < NOW() - INTERVAL '2 minutes'$$
);

-- ── 3. Replace complete_feed_round_with_log with rate-limit guard ─────────────
-- Identical signature to Epic 7 (20260516000000) — all callers unaffected.
-- The original logic is preserved verbatim; only the rate-limit preamble is new.
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
  v_user_id           UUID      := auth.uid();
  v_call_count        INTEGER;
  v_rate_limit        CONSTANT INTEGER := 60;
  v_ts                TIMESTAMP := COALESCE(p_created_at::TIMESTAMP, NOW());
  v_success           BOOLEAN   := FALSE;
  v_already_completed BOOLEAN   := FALSE;
  v_log_inserted      BOOLEAN   := FALSE;
  v_op_duplicate      BOOLEAN   := FALSE;
  v_error_msg         TEXT      := NULL;
BEGIN
  -- ── Rate-limit check ───────────────────────────────────────────────────────
  SELECT COUNT(*) INTO v_call_count
  FROM public.feed_rpc_rate_limit
  WHERE user_id = v_user_id
    AND called_at > NOW() - INTERVAL '1 minute';

  IF v_call_count >= v_rate_limit THEN
    RETURN jsonb_build_object(
      'success', FALSE,
      'error',   'Rate limit exceeded — too many feed requests in 1 minute'
    );
  END IF;

  INSERT INTO public.feed_rpc_rate_limit (user_id, called_at)
  VALUES (v_user_id, NOW());

  -- ── Original Epic 7 logic (unchanged) ─────────────────────────────────────
  BEGIN
    -- Guard 1: operation_id exact-once check
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

    -- Guard 2: feed_rounds already-completed check
    IF EXISTS (
      SELECT 1 FROM public.feed_rounds
      WHERE pond_id = p_pond_id
        AND doc     = p_doc
        AND round   = p_round
        AND status  = 'completed'
    ) THEN
      v_already_completed := TRUE;
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

    -- UPSERT feed_logs
    INSERT INTO public.feed_logs (
      pond_id, doc, round, feed_given, base_feed, operation_id, created_at, updated_at
    ) VALUES (
      p_pond_id, p_doc, p_round, p_feed_amount, p_base_feed, p_operation_id, v_ts, NOW()
    )
    ON CONFLICT (pond_id, doc, round) DO UPDATE
       SET feed_given   = EXCLUDED.feed_given,
           base_feed    = EXCLUDED.base_feed,
           operation_id = COALESCE(EXCLUDED.operation_id, feed_logs.operation_id),
           updated_at   = NOW();

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

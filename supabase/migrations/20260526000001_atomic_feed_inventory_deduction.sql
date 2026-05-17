-- Make inventory deduction atomic with feed log insertion.
--
-- Problem: _deductInventoryStock in the app fires as a separate async call
-- after the RPC completes. An app crash between the two leaves phantom inventory.
--
-- Fix: Fold the deduction into complete_feed_round_with_log so both writes
-- happen in the same DB transaction. The app-side call is removed after this.
--
-- Deduction is skipped when:
--   • operationDuplicate = TRUE (fast-path return — no writes at all)
--   • alreadyCompleted   = TRUE (repair UPSERT — round was done before, don't double-deduct)
--   • No matching inventory item found for the farm (best-effort, non-fatal)

DROP FUNCTION IF EXISTS public.complete_feed_round_with_log(
  UUID, INTEGER, INTEGER, DOUBLE PRECISION, DOUBLE PRECISION, TEXT, UUID
);

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
  v_farm_id           UUID;
  v_feed_item_id      UUID;
BEGIN
  BEGIN

    -- ── Guard 1: operation_id exact-once check ─────────────────────────────
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

    -- ── UPSERT feed_logs ───────────────────────────────────────────────────
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

    -- ── Atomic inventory deduction (only on first completion, not repair) ──
    -- Skip if this is a repair UPSERT (alreadyCompleted) to avoid double-deduction.
    IF NOT v_already_completed THEN
      SELECT p.farm_id INTO v_farm_id
        FROM public.ponds p
       WHERE p.id = p_pond_id;

      IF v_farm_id IS NOT NULL THEN
        SELECT ii.id INTO v_feed_item_id
          FROM public.inventory_items ii
         WHERE ii.farm_id = v_farm_id
           AND ii.category = 'feed'
           AND (ii.is_auto_tracked IS TRUE OR ii.is_auto_tracked IS NULL)
           AND (ii.deleted_at IS NULL)
         LIMIT 1;

        IF v_feed_item_id IS NOT NULL THEN
          INSERT INTO public.inventory_consumption (
            item_id, source, quantity_used, date
          ) VALUES (
            v_feed_item_id, 'feed_auto', p_feed_amount, CURRENT_DATE
          );
        END IF;
      END IF;
    END IF;

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
  'Idempotent feed round completion: writes feed_rounds + feed_logs + inventory_consumption in one transaction. '
  'operation_id guard ensures exact-once semantics across app retries and crashes.';

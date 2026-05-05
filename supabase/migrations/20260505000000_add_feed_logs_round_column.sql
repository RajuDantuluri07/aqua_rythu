-- Migration: Add feed_logs table with round column support
-- Purpose: Fix blocker issue where feed_logs.round column is missing
-- This prevents feed confirmation from working

-- Step 1: Create feed_logs table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.feed_logs (
  id                  UUID          DEFAULT gen_random_uuid() PRIMARY KEY,
  pond_id             UUID          NOT NULL REFERENCES public.ponds(id) ON DELETE CASCADE,
  doc                 INTEGER       NOT NULL,
  round               INTEGER       DEFAULT 1,
  feed_given          NUMERIC       DEFAULT 0,
  base_feed           NUMERIC,
  feed_round_id       UUID          REFERENCES public.feed_rounds(id) ON DELETE CASCADE,
  tray_leftover       NUMERIC,
  stocking_type       TEXT,
  density             INTEGER,
  created_at          TIMESTAMPTZ   DEFAULT now(),
  updated_at          TIMESTAMPTZ   DEFAULT now()
);

-- Step 2: Add round column if it doesn't exist (for existing tables)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'feed_logs'
  ) THEN
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'feed_logs'
        AND column_name = 'round'
    ) THEN
      ALTER TABLE public.feed_logs ADD COLUMN round INTEGER DEFAULT 1;
    END IF;
  END IF;
END $$;

-- Step 3: Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_feed_logs_pond_id ON public.feed_logs(pond_id);
CREATE INDEX IF NOT EXISTS idx_feed_logs_doc ON public.feed_logs(doc);
CREATE INDEX IF NOT EXISTS idx_feed_logs_round ON public.feed_logs(round);
CREATE INDEX IF NOT EXISTS idx_feed_logs_pond_doc_round ON public.feed_logs(pond_id, doc, round);
CREATE INDEX IF NOT EXISTS idx_feed_logs_feed_round_id ON public.feed_logs(feed_round_id);

-- Step 4: Add UNIQUE constraint on (pond_id, doc, round) if not exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE table_schema = 'public'
      AND table_name = 'feed_logs'
      AND constraint_type = 'UNIQUE'
      AND constraint_name = 'uq_feed_logs_pond_doc_round'
  ) THEN
    ALTER TABLE public.feed_logs
    ADD CONSTRAINT uq_feed_logs_pond_doc_round UNIQUE (pond_id, doc, round);
  END IF;
END $$;

-- Step 5: Enable RLS and create policies
ALTER TABLE public.feed_logs ENABLE ROW LEVEL SECURITY;

-- Allow read access to own ponds' feed logs
CREATE POLICY IF NOT EXISTS "feed_logs_select"
  ON public.feed_logs FOR SELECT
  USING (pond_id IN (SELECT id FROM public.ponds WHERE user_id = auth.uid()));

-- Allow insert access to own ponds' feed logs
CREATE POLICY IF NOT EXISTS "feed_logs_insert"
  ON public.feed_logs FOR INSERT
  WITH CHECK (pond_id IN (SELECT id FROM public.ponds WHERE user_id = auth.uid()));

-- Allow update access to own ponds' feed logs
CREATE POLICY IF NOT EXISTS "feed_logs_update"
  ON public.feed_logs FOR UPDATE
  USING (pond_id IN (SELECT id FROM public.ponds WHERE user_id = auth.uid()));

-- Allow delete access to own ponds' feed logs
CREATE POLICY IF NOT EXISTS "feed_logs_delete"
  ON public.feed_logs FOR DELETE
  USING (pond_id IN (SELECT id FROM public.ponds WHERE user_id = auth.uid()));

-- Step 6: Add trigger for updated_at column
CREATE OR REPLACE FUNCTION public.update_feed_logs_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS feed_logs_updated_at ON public.feed_logs;
CREATE TRIGGER feed_logs_updated_at
  BEFORE UPDATE ON public.feed_logs
  FOR EACH ROW EXECUTE FUNCTION update_feed_logs_updated_at();

-- Step 7: Ensure RPC functions have correct schema references
CREATE OR REPLACE FUNCTION public.complete_feed_round_with_log(
  p_pond_id      UUID,
  p_doc          INTEGER,
  p_round        INTEGER,
  p_feed_amount  DOUBLE PRECISION,
  p_base_feed    DOUBLE PRECISION DEFAULT NULL,
  p_created_at   TEXT            DEFAULT NULL
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_ts         TIMESTAMP := COALESCE(p_created_at::TIMESTAMP, NOW());
  v_success     BOOLEAN := FALSE;
  v_already_completed BOOLEAN := FALSE;
  v_log_inserted BOOLEAN := FALSE;
  v_error_msg   TEXT := NULL;
BEGIN
  BEGIN
    -- Check if round is already completed
    IF EXISTS (
      SELECT 1 FROM public.feed_rounds
      WHERE pond_id = p_pond_id
        AND doc   = p_doc
        AND round = p_round
        AND status = 'completed'
    ) THEN
      v_already_completed := TRUE;
      v_success := TRUE;
      RAISE NOTICE 'Round already completed - idempotent';
    ELSE
      -- Mark the round complete (UPDATE if row exists, INSERT otherwise)
      UPDATE public.feed_rounds
      SET status        = 'completed',
          actual_amount = p_feed_amount,
          updated_at    = NOW()
      WHERE pond_id = p_pond_id
        AND doc   = p_doc
        AND round = p_round;

      IF NOT FOUND THEN
        INSERT INTO public.feed_rounds (
          pond_id, doc, round, planned_amount, actual_amount, status, updated_at
        ) VALUES (
          p_pond_id, p_doc, p_round, p_feed_amount, p_feed_amount, 'completed', NOW()
        );
      END IF;

      -- Save individual round entry to feed_logs using UPSERT (prevents race condition)
      -- This ensures atomicity: either insert or update, never fails on constraint violation
      INSERT INTO public.feed_logs (
        pond_id, doc, round, feed_given, base_feed, created_at, updated_at
      ) VALUES (
        p_pond_id, p_doc, p_round, p_feed_amount, p_base_feed, v_ts, NOW()
      )
      ON CONFLICT (pond_id, doc, round) DO UPDATE SET
        feed_given = EXCLUDED.feed_given,
        base_feed = EXCLUDED.base_feed,
        updated_at = NOW()
      ;

      -- Mark log as inserted (UPSERT always "inserts" from a sequence perspective)
      v_log_inserted := TRUE;

      v_success := TRUE;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    v_success := FALSE;
    v_error_msg := SQLERRM;
    RAISE NOTICE 'Error in complete_feed_round_with_log: %', v_error_msg;
  END;

  -- Return structured JSON response
  RETURN jsonb_build_object(
    'success', v_success,
    'alreadyCompleted', v_already_completed,
    'logInserted', v_log_inserted,
    'error', v_error_msg
  );
END;
$$;

COMMENT ON COLUMN public.feed_logs.round IS 'Feed round number (1-4 typically per day)';
COMMENT ON COLUMN public.feed_logs.pond_id IS 'Reference to pond';
COMMENT ON COLUMN public.feed_logs.doc IS 'Days of culture';
COMMENT ON COLUMN public.feed_logs.feed_given IS 'Actual feed amount given (kg)';
COMMENT ON COLUMN public.feed_logs.base_feed IS 'Base feed amount before adjustments (kg)';

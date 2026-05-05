-- =============================================================
-- Fix 1: Create inventory_items table (referenced by add_stock RPC)
-- =============================================================
CREATE TABLE IF NOT EXISTS public.inventory_items (
  id              UUID          DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id         UUID          REFERENCES auth.users(id) ON DELETE SET NULL,
  farm_id         UUID          NOT NULL REFERENCES public.farms(id) ON DELETE CASCADE,
  name            TEXT          NOT NULL,
  category        TEXT          NOT NULL,
  unit            TEXT          NOT NULL DEFAULT 'kg',
  opening_quantity NUMERIC      NOT NULL DEFAULT 0,
  price_per_unit  NUMERIC,
  is_auto_tracked BOOLEAN       NOT NULL DEFAULT false,
  pack_size       NUMERIC,
  pack_label      TEXT          DEFAULT 'pack',
  cost_per_pack   NUMERIC,
  created_at      TIMESTAMPTZ   DEFAULT now(),
  updated_at      TIMESTAMPTZ   DEFAULT now()
);

ALTER TABLE public.inventory_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "inventory_items_select"
  ON public.inventory_items FOR SELECT
  USING (farm_id IN (SELECT id FROM public.farms WHERE user_id = auth.uid()));

CREATE POLICY "inventory_items_insert"
  ON public.inventory_items FOR INSERT
  WITH CHECK (farm_id IN (SELECT id FROM public.farms WHERE user_id = auth.uid()));

CREATE POLICY "inventory_items_update"
  ON public.inventory_items FOR UPDATE
  USING (farm_id IN (SELECT id FROM public.farms WHERE user_id = auth.uid()));

CREATE TRIGGER inventory_items_updated_at
  BEFORE UPDATE ON public.inventory_items
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =============================================================
-- Fix 2: Create inventory_stock_view (used by getInventoryStock)
-- =============================================================
CREATE OR REPLACE VIEW public.inventory_stock_view AS
SELECT
  ii.id,
  ii.farm_id,
  NULL::uuid          AS crop_id,
  ii.user_id,
  ii.name,
  ii.category,
  ii.unit,
  ii.opening_quantity AS current_quantity,
  ii.pack_size,
  ii.pack_label,
  ii.price_per_unit,
  ii.cost_per_pack,
  ii.is_auto_tracked,
  ii.created_at,
  ii.updated_at
FROM public.inventory_items ii;

-- =============================================================
-- Fix 3: safe_insert_feed_log — idempotent round-level feed log insert
-- Returns TRUE if inserted, FALSE if a log already exists for
-- the same pond + DOC + round (duplicate guard).
-- Each round creates its own row — no daily aggregation.
-- =============================================================
CREATE OR REPLACE FUNCTION public.safe_insert_feed_log(
  p_pond_id       UUID,
  p_doc           INTEGER,
  p_round         INTEGER         DEFAULT 1,
  p_feed_given    NUMERIC         DEFAULT 0,
  p_base_feed     DOUBLE PRECISION DEFAULT NULL,
  p_created_at    TEXT            DEFAULT NULL,
  p_tray_leftover DOUBLE PRECISION DEFAULT NULL,
  p_stocking_type TEXT            DEFAULT NULL,
  p_density       INTEGER         DEFAULT NULL
) RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_ts   TIMESTAMP := COALESCE(p_created_at::TIMESTAMP, NOW());
BEGIN
  -- 🔒 FIX: Check on (pond_id, doc, round) — not DATE
  -- This allows multiple rounds per day, each with its own row
  IF EXISTS (
    SELECT 1 FROM public.feed_logs
    WHERE pond_id = p_pond_id
      AND doc     = p_doc
      AND round   = p_round
  ) THEN
    RETURN FALSE;
  END IF;

  -- 🔒 FIX: Include 'round' in INSERT so each round is tracked separately
  INSERT INTO public.feed_logs (
    pond_id, doc, round, feed_given, base_feed,
    tray_leftover, stocking_type, density, created_at
  ) VALUES (
    p_pond_id, p_doc, p_round, p_feed_given, p_base_feed,
    p_tray_leftover, p_stocking_type, p_density, v_ts
  );

  RETURN TRUE;
END;
$$;

-- =============================================================
-- Fix 4: complete_feed_round_with_log — atomic round completion
-- Marks feed_rounds as completed and saves individual round entries
-- in feed_logs (one row per round, not daily aggregates).
-- Returns FALSE on duplicate round completion.
-- =============================================================
CREATE OR REPLACE FUNCTION public.complete_feed_round_with_log(
  p_pond_id      UUID,
  p_doc          INTEGER,
  p_round        INTEGER,
  p_feed_amount  DOUBLE PRECISION,
  p_base_feed    DOUBLE PRECISION DEFAULT NULL,
  p_created_at   TEXT            DEFAULT NULL
) RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_ts   TIMESTAMP := COALESCE(p_created_at::TIMESTAMP, NOW());
BEGIN
  -- Idempotency: if this round is already completed, reject as duplicate
  IF EXISTS (
    SELECT 1 FROM public.feed_rounds
    WHERE pond_id = p_pond_id
      AND doc   = p_doc
      AND round = p_round
      AND status = 'completed'
  ) THEN
    RETURN FALSE;
  END IF;

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

  -- 🔒 FIX: Save individual round entry to feed_logs (not daily aggregate)
  -- Each round gets its own row keyed on (pond_id, doc, round)
  IF EXISTS (
    SELECT 1 FROM public.feed_logs
    WHERE pond_id = p_pond_id
      AND doc     = p_doc
      AND round   = p_round
  ) THEN
    -- Update existing round entry
    UPDATE public.feed_logs
    SET feed_given = p_feed_amount,
        base_feed = COALESCE(p_base_feed, base_feed),
        updated_at = NOW()
    WHERE pond_id = p_pond_id
      AND doc     = p_doc
      AND round   = p_round;
  ELSE
    -- Insert new round entry
    INSERT INTO public.feed_logs (
      pond_id, doc, round, feed_given, base_feed, created_at
    ) VALUES (
      p_pond_id, p_doc, p_round, p_feed_amount, p_base_feed, v_ts
    );
  END IF;

  RETURN TRUE;
END;
$$;

-- =============================================================
-- Fix 5: expenses table schema mismatch
-- App inserts: user_id, farm_id, crop_id, notes, date
-- DB had:      note (wrong name), no user_id/farm_id/crop_id/date
-- =============================================================
ALTER TABLE public.expenses ALTER COLUMN pond_id DROP NOT NULL;
ALTER TABLE public.expenses ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id);
ALTER TABLE public.expenses ADD COLUMN IF NOT EXISTS farm_id UUID REFERENCES public.farms(id) ON DELETE CASCADE;
ALTER TABLE public.expenses ADD COLUMN IF NOT EXISTS crop_id UUID REFERENCES public.crop_cycles(id) ON DELETE SET NULL;
ALTER TABLE public.expenses ADD COLUMN IF NOT EXISTS date    DATE DEFAULT CURRENT_DATE;

-- Rename note → notes to match app field name (preserves existing data)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name  = 'expenses'
      AND column_name = 'note'
  ) THEN
    ALTER TABLE public.expenses RENAME COLUMN note TO notes;
  END IF;
END $$;

-- Back-fill date from created_at for existing rows
UPDATE public.expenses SET date = DATE(created_at) WHERE date IS NULL;

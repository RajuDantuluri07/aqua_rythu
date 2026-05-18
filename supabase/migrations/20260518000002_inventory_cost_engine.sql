-- Cost columns on inventory_entries (snapshotted at purchase time, never updated)
ALTER TABLE public.inventory_entries
  ADD COLUMN IF NOT EXISTS bag_price  numeric,
  ADD COLUMN IF NOT EXISTS total_cost numeric,
  ADD COLUMN IF NOT EXISTS batch_id   uuid;

-- Batch header: one row per Save Inventory session
CREATE TABLE IF NOT EXISTS public.inventory_batches (
  id             uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  farm_id        uuid        NOT NULL REFERENCES public.farms(id),
  user_id        uuid        NOT NULL REFERENCES auth.users(id),
  purchase_date  date        NOT NULL,
  total_products integer     NOT NULL,
  total_cost     numeric,
  created_at     timestamptz DEFAULT now()
);

ALTER TABLE public.inventory_batches ENABLE ROW LEVEL SECURITY;

CREATE POLICY inventory_batches_select ON public.inventory_batches
  FOR SELECT USING (is_farm_member(farm_id));

CREATE POLICY inventory_batches_insert ON public.inventory_batches
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM public.farms WHERE id = farm_id AND user_id = auth.uid())
  );

NOTIFY pgrst, 'reload schema';

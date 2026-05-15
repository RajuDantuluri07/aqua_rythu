-- inventory_entries: product-master-linked purchase records
-- Stores only product_id + quantity. All metadata comes from master tables.

CREATE TABLE IF NOT EXISTS public.inventory_entries (
  id               UUID          DEFAULT gen_random_uuid() PRIMARY KEY,
  farm_id          UUID          NOT NULL REFERENCES public.farms(id) ON DELETE CASCADE,
  pond_id          UUID          REFERENCES public.ponds(id) ON DELETE SET NULL,
  product_id       UUID          NOT NULL,
  product_type     TEXT          NOT NULL CHECK (product_type IN ('feed', 'supplement')),
  quantity_purchased NUMERIC     NOT NULL CHECK (quantity_purchased > 0),
  quantity_unit    TEXT          NOT NULL,
  purchase_date    DATE          NOT NULL DEFAULT CURRENT_DATE,
  notes            TEXT,
  user_id          UUID          REFERENCES auth.users(id),
  created_at       TIMESTAMPTZ   DEFAULT now()
);

ALTER TABLE public.inventory_entries ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage their own inventory entries"
  ON public.inventory_entries
  FOR ALL
  USING (user_id = auth.uid());

CREATE INDEX idx_inventory_entries_farm     ON public.inventory_entries(farm_id);
CREATE INDEX idx_inventory_entries_product  ON public.inventory_entries(product_id, product_type);
CREATE INDEX idx_inventory_entries_date     ON public.inventory_entries(farm_id, purchase_date DESC);

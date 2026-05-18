-- inventory_entries: product-master-linked purchase log.
-- Distinct from inventory_purchases (which links to inventory_items master records).
-- This table records batch purchases directly from the Add Inventory screen,
-- keyed to FeedMasterProduct / ProductMaster IDs.
CREATE TABLE public.inventory_entries (
  id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  farm_id             uuid        NOT NULL REFERENCES public.farms(id),
  user_id             uuid        NOT NULL REFERENCES auth.users(id),
  product_id          uuid        NOT NULL,
  product_type        text        NOT NULL CHECK (product_type IN ('feed', 'supplement')),
  quantity_purchased  integer     NOT NULL CHECK (quantity_purchased > 0),
  package_size        numeric,
  package_unit        text,
  actual_stock        numeric,
  quantity_unit       text,
  purchase_date       date        NOT NULL DEFAULT CURRENT_DATE,
  created_at          timestamptz DEFAULT now()
);

ALTER TABLE public.inventory_entries ENABLE ROW LEVEL SECURITY;

CREATE POLICY inventory_entries_select ON public.inventory_entries
  FOR SELECT USING (is_farm_member(farm_id));

CREATE POLICY inventory_entries_insert ON public.inventory_entries
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM public.farms WHERE id = farm_id AND user_id = auth.uid())
  );

CREATE POLICY inventory_entries_delete ON public.inventory_entries
  FOR DELETE USING (
    EXISTS (SELECT 1 FROM public.farms WHERE id = farm_id AND user_id = auth.uid())
  );

-- Notify PostgREST to reload its schema cache
NOTIFY pgrst, 'reload schema';

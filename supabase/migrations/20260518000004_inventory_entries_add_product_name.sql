ALTER TABLE public.inventory_entries
  ADD COLUMN IF NOT EXISTS product_name text;

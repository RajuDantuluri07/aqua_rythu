-- Task 3D: Add FK constraint on inventory_items.farm_id
-- Task 3E: Add soft delete (deleted_at) to inventory_items
--
-- The FK ensures orphaned inventory items are impossible if a farm is deleted.
-- Soft delete preserves the audit trail (purchase history, consumption records)
-- while hiding the item from active views.

-- ── Task 3D: FK on farm_id ─────────────────────────────────────────────────
-- Guard: only add if the constraint doesn't already exist.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name = 'fk_inventory_items_farm'
      AND table_name = 'inventory_items'
  ) THEN
    ALTER TABLE public.inventory_items
      ADD CONSTRAINT fk_inventory_items_farm
      FOREIGN KEY (farm_id) REFERENCES public.farms(id) ON DELETE CASCADE;
  END IF;
END $$;

-- ── Task 3E: Soft delete ───────────────────────────────────────────────────
ALTER TABLE public.inventory_items
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ DEFAULT NULL;

-- Index for the common "active items" filter pattern.
CREATE INDEX IF NOT EXISTS idx_inventory_items_active
  ON public.inventory_items(farm_id, category)
  WHERE deleted_at IS NULL;

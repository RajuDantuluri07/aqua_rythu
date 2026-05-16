-- TICKET-029: Strengthen inventory_entries RLS to use farm ownership chain.
--
-- Original policy (20260517000000_inventory_entries.sql:20):
--   USING (user_id = auth.uid())
--
-- This is weaker than the pattern used elsewhere in the schema because:
--   (a) It relies on user_id being correctly populated on every insert.
--       A bug that omits user_id produces orphaned rows invisible to everyone.
--   (b) It is inconsistent with inventory_items and farms, which use farm ownership.
--
-- Fix: replace with farm ownership chain — the same pattern as inventory_items.
-- This makes user_id purely a soft audit column; access is controlled by whether
-- the user owns the farm the entry belongs to. The TICKET-022 migration already
-- makes user_id NOT NULL, providing belt-and-suspenders.

DROP POLICY IF EXISTS "Users can manage their own inventory entries"
  ON public.inventory_entries;

CREATE POLICY "inventory_entries_farm_owner"
  ON public.inventory_entries FOR ALL
  USING (
    farm_id IN (SELECT id FROM public.farms WHERE user_id = auth.uid())
  )
  WITH CHECK (
    farm_id IN (SELECT id FROM public.farms WHERE user_id = auth.uid())
  );

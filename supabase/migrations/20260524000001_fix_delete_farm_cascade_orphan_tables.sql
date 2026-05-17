-- BUG-QA-006: Fix delete_farm_cascade — missing orphan table deletions.
--
-- The original function (20260520030000_delete_farm_cascade_with_ownership.sql)
-- omitted four tables that reference ponds:
--   sampling_logs, harvest_logs, expenses, inventory_entries
--
-- Impact: deleting a farm left orphaned rows in these tables, violating referential
-- integrity and leaking user data that was intended to be removed.
--
-- Fix: add DELETE statements for all four tables before the pond DELETE.

CREATE OR REPLACE FUNCTION delete_farm_cascade(
  p_farm_id UUID,
  p_user_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Ownership check: reject if the farm does not belong to p_user_id.
  IF NOT EXISTS (
    SELECT 1 FROM public.farms
    WHERE id = p_farm_id
      AND user_id = p_user_id
      AND user_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'Farm not found or access denied';
  END IF;

  -- Delete all child records in dependency order (deepest first).
  DELETE FROM public.feed_logs         WHERE pond_id IN (SELECT id FROM public.ponds WHERE farm_id = p_farm_id);
  DELETE FROM public.feed_rounds       WHERE pond_id IN (SELECT id FROM public.ponds WHERE farm_id = p_farm_id);
  DELETE FROM public.water_logs        WHERE pond_id IN (SELECT id FROM public.ponds WHERE farm_id = p_farm_id);
  DELETE FROM public.tray_logs         WHERE pond_id IN (SELECT id FROM public.ponds WHERE farm_id = p_farm_id);
  DELETE FROM public.samplings         WHERE pond_id IN (SELECT id FROM public.ponds WHERE farm_id = p_farm_id);
  DELETE FROM public.sampling_logs     WHERE pond_id IN (SELECT id FROM public.ponds WHERE farm_id = p_farm_id);
  DELETE FROM public.harvest_logs      WHERE pond_id IN (SELECT id FROM public.ponds WHERE farm_id = p_farm_id);
  DELETE FROM public.expenses          WHERE pond_id IN (SELECT id FROM public.ponds WHERE farm_id = p_farm_id);
  DELETE FROM public.inventory_entries WHERE pond_id IN (SELECT id FROM public.ponds WHERE farm_id = p_farm_id);
  DELETE FROM public.farm_members      WHERE farm_id = p_farm_id;
  DELETE FROM public.ponds             WHERE farm_id = p_farm_id;
  DELETE FROM public.farms             WHERE id = p_farm_id AND user_id = p_user_id;
END;
$$;

GRANT EXECUTE ON FUNCTION delete_farm_cascade(UUID, UUID) TO authenticated;

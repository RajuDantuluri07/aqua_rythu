-- TICKET-015: Define delete_farm_cascade RPC with ownership verification.
--
-- This function is called by farm_service.dart FarmService.deleteFarm() with
-- both p_farm_id and p_user_id. It must verify farm ownership before deleting
-- any data so a user cannot delete another user's farm by guessing a farm UUID.
--
-- The function is SECURITY DEFINER so it can cascade-delete child rows that
-- are protected by RLS policies (ponds, feed_rounds, feed_logs, etc.).
-- The ownership guard runs first and raises an exception if the farm does not
-- belong to the caller, preventing privilege escalation.

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
  -- Using p_user_id (passed from client) compared against farms.user_id;
  -- the edge-function / RPC caller must pass auth.uid() — verified below.
  IF NOT EXISTS (
    SELECT 1 FROM public.farms
    WHERE id = p_farm_id
      AND user_id = p_user_id
      AND user_id = auth.uid()   -- extra guard: p_user_id must also match JWT
  ) THEN
    RAISE EXCEPTION 'Farm not found or access denied';
  END IF;

  -- Delete all child records in dependency order.
  -- feed_logs and feed_rounds reference ponds; ponds reference farms.
  DELETE FROM public.feed_logs     WHERE pond_id IN (SELECT id FROM public.ponds WHERE farm_id = p_farm_id);
  DELETE FROM public.feed_rounds   WHERE pond_id IN (SELECT id FROM public.ponds WHERE farm_id = p_farm_id);
  DELETE FROM public.water_logs    WHERE pond_id IN (SELECT id FROM public.ponds WHERE farm_id = p_farm_id);
  DELETE FROM public.tray_logs     WHERE pond_id IN (SELECT id FROM public.ponds WHERE farm_id = p_farm_id);
  DELETE FROM public.samplings     WHERE pond_id IN (SELECT id FROM public.ponds WHERE farm_id = p_farm_id);
  DELETE FROM public.farm_members  WHERE farm_id = p_farm_id;
  DELETE FROM public.ponds         WHERE farm_id = p_farm_id;
  DELETE FROM public.farms         WHERE id = p_farm_id AND user_id = p_user_id;
END;
$$;

GRANT EXECUTE ON FUNCTION delete_farm_cascade(UUID, UUID) TO authenticated;

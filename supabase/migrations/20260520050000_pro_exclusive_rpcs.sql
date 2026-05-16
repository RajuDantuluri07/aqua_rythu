-- TICKET-012: SECURITY DEFINER RPCs for PRO-exclusive analytics.
--
-- PRO features (smart feed, FCR, growth insights, cross-pond comparison) are
-- currently gated only at the Flutter UI layer via featureGateProvider.
-- A bypass at the UI layer (e.g. reverse-engineering the API) allows a FREE
-- user to read the underlying Supabase tables directly.
--
-- This migration adds server-side enforcement via SECURITY DEFINER RPCs that
-- call has_active_pro() before returning sensitive analytical data. Dart code
-- should migrate to calling these RPCs instead of direct table SELECT for
-- PRO-exclusive features.

-- ── get_samplings_for_pond ────────────────────────────────────────────────────
-- Returns all sampling rows for a pond. Requires PRO subscription.
-- Samplings drive smart feed (DOC > 30) and ABW-based FCR calculations.
CREATE OR REPLACE FUNCTION get_samplings_for_pond(p_pond_id UUID)
RETURNS SETOF samplings
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Verify pond belongs to caller (prevents data leak via pond UUID enumeration)
  IF NOT EXISTS (
    SELECT 1 FROM ponds p
    JOIN farms f ON f.id = p.farm_id
    WHERE p.id = p_pond_id AND f.user_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'Pond not found or access denied';
  END IF;

  -- PRO gate
  IF NOT has_active_pro() THEN
    RAISE EXCEPTION 'PRO subscription required to access sampling data';
  END IF;

  RETURN QUERY
    SELECT * FROM samplings
    WHERE pond_id = p_pond_id
    ORDER BY created_at DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION get_samplings_for_pond(UUID) TO authenticated;

-- ── get_water_logs_for_pond ───────────────────────────────────────────────────
-- Returns water quality logs for a pond. Requires PRO subscription.
-- Water log data (DO, pH, ammonia) is used by the smart feed engine
-- (environment factor correction) which is PRO-only.
CREATE OR REPLACE FUNCTION get_water_logs_for_pond(p_pond_id UUID)
RETURNS SETOF water_logs
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM ponds p
    JOIN farms f ON f.id = p.farm_id
    WHERE p.id = p_pond_id AND f.user_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'Pond not found or access denied';
  END IF;

  IF NOT has_active_pro() THEN
    RAISE EXCEPTION 'PRO subscription required to access water quality data';
  END IF;

  RETURN QUERY
    SELECT * FROM water_logs
    WHERE pond_id = p_pond_id
    ORDER BY created_at DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION get_water_logs_for_pond(UUID) TO authenticated;

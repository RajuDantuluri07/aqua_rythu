-- TICKET-016: Ensure app_config RLS blocks client access to sensitive keys.
--
-- The app_config table stores both public configuration (feed engine params,
-- pricing, announcements) and sensitive admin data (admin_passcode).
-- If RLS is not enforced, or if the SELECT policy allows reading all rows,
-- a client could query the admin_passcode key directly without going through
-- the validate-admin-passcode edge function.
--
-- Fix: enable RLS (idempotent) and create a row-level SELECT policy that
-- excludes any row whose key contains 'passcode' or 'secret'.
-- Writes remain service_role-only (no client INSERT/UPDATE/DELETE policies).

ALTER TABLE public.app_config ENABLE ROW LEVEL SECURITY;

-- Drop any existing broad SELECT policy before replacing it.
DROP POLICY IF EXISTS "Anyone can read app_config"  ON public.app_config;
DROP POLICY IF EXISTS "Authenticated read app_config" ON public.app_config;

-- Narrow SELECT: authenticated users may read any row EXCEPT sensitive keys.
CREATE POLICY "Authenticated read non-sensitive config"
  ON public.app_config FOR SELECT
  TO authenticated
  USING (
    key NOT ILIKE '%passcode%'
    AND key NOT ILIKE '%secret%'
    AND key NOT ILIKE '%password%'
  );

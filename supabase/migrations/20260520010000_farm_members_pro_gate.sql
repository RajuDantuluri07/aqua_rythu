-- TICKET-005: Gate farm member invites behind the PRO subscription.
--
-- The original farm_members_insert policy (20260514000000) only checks
-- farm ownership — it allows any FREE user to add unlimited team members,
-- which is intended to be a PRO-only feature.
--
-- Fix: replace the INSERT policy with one that also requires an active PRO
-- subscription via the existing has_active_pro() SECURITY DEFINER function.
-- Service-role writes (e.g. admin tooling) bypass RLS and are unaffected.

DROP POLICY IF EXISTS "farm_members_insert" ON public.farm_members;

CREATE POLICY "farm_members_insert"
  ON public.farm_members FOR INSERT
  WITH CHECK (
    farm_id IN (SELECT id FROM public.farms WHERE user_id = auth.uid())
    AND has_active_pro()
  );

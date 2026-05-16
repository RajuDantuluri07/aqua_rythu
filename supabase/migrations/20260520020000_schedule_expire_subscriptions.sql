-- TICKET-008: Schedule expire_subscriptions() to run nightly via pg_cron.
--
-- The expire_subscriptions() function was defined in
-- 20260503000000_payment_hardening.sql but was never scheduled.
-- Without this cron job, expired subscriptions remain active in the DB;
-- the only guard is the client-side / RPC expiry check in
-- get_active_entitlement(). This migration wires up the nightly sweep
-- so DB rows reflect the truth and admin queries/reporting are accurate.
--
-- Runs at 01:00 UTC daily. Requires pg_cron extension (enabled by default
-- on Supabase projects). Uses the cron schema.

SELECT cron.schedule(
  'expire-subscriptions-nightly',
  '0 1 * * *',
  $$SELECT expire_subscriptions()$$
);

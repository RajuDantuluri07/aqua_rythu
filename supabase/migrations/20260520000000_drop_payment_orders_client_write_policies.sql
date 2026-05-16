-- TICKET-003: Remove client-writable RLS policies on payment_orders.
--
-- These policies were created in 20260503010000_payment_observability.sql and
-- allow any authenticated user to INSERT or UPDATE payment_orders rows where
-- user_id matches auth.uid(). This is dangerous: a malicious client could
-- craft a fake order row and then attempt to verify it against our edge
-- function, potentially activating a PRO subscription without paying.
--
-- Payment orders must only be written by the create-razorpay-order edge
-- function (service_role key). Dropping the client-writable policies here
-- means only service_role can write; authenticated users can SELECT their own.
DROP POLICY IF EXISTS "Service inserts orders" ON payment_orders;
DROP POLICY IF EXISTS "Service updates orders" ON payment_orders;

-- Keep the SELECT policy so the app can query its own order history.
-- (No new policies needed — service_role bypasses RLS for writes.)

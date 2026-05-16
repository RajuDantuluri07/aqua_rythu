-- Allow authenticated users to INSERT their own client-side payment events
-- (cancelled, failed, initiated) into payment_logs.
--
-- Security constraints:
--   source must be 'client'  — prevents faking webhook events
--   status restricted to non-success values — prevents self-granting PRO
--   user_id must match auth.uid() — row-level isolation
--
-- Server-side events (success, webhook_received, retry) continue to be
-- written exclusively by edge functions using service_role, which bypasses RLS.
CREATE POLICY "Users insert own client events"
  ON payment_logs FOR INSERT
  WITH CHECK (
    auth.uid() = user_id
    AND source = 'client'
    AND status IN ('cancelled', 'failed', 'initiated')
  );

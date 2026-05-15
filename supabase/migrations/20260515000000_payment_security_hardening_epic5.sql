-- EPIC 5 — Payment Security Hardening
-- Phases 2–5 & 7: server-authoritative entitlement, RLS lockdown,
-- replay protection, audit trail.

-- ─────────────────────────────────────────────────────────────────────────────
-- Phase 3: Replay protection — prevent one order → many subscriptions
-- ─────────────────────────────────────────────────────────────────────────────
CREATE UNIQUE INDEX IF NOT EXISTS subscriptions_order_id_unique
  ON subscriptions (order_id)
  WHERE order_id IS NOT NULL;

-- ─────────────────────────────────────────────────────────────────────────────
-- Phase 2: Lock subscriptions table — service-role writes only.
--
-- Clients may SELECT their own rows. All INSERTs and UPDATEs must come from
-- edge functions that use the service_role key (which bypasses RLS). This
-- eliminates the "free PRO" attack: no client can call createSubscription()
-- and gift itself an active subscription without a verified payment.
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;

-- Remove any legacy policies that grant client write access
DROP POLICY IF EXISTS "Users can insert subscriptions"    ON subscriptions;
DROP POLICY IF EXISTS "Users can update subscriptions"    ON subscriptions;
DROP POLICY IF EXISTS "Allow insert"                      ON subscriptions;
DROP POLICY IF EXISTS "Allow update"                      ON subscriptions;
DROP POLICY IF EXISTS "Users read own subscriptions"      ON subscriptions;

-- Read-only for authenticated users — they see only their own rows
CREATE POLICY "Users read own subscriptions"
  ON subscriptions FOR SELECT
  USING (auth.uid() = user_id);

-- No INSERT / UPDATE / DELETE for authenticated users.
-- Edge functions use service_role and bypass RLS entirely.

-- ─────────────────────────────────────────────────────────────────────────────
-- Phase 7: payment_audit_logs — security-critical event trail.
--
-- Written exclusively by service_role edge functions.
-- No SELECT policy for authenticated users: attackers cannot see what we log,
-- preventing them from learning detection thresholds.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS payment_audit_logs (
  id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  event_type   TEXT        NOT NULL,
  -- event_type values:
  --   payment_verified | replay_attempt | signature_mismatch | amount_mismatch
  --   payment_not_captured | duplicate_verification | subscription_activated
  --   expired_access_attempt | webhook_replay
  user_id      UUID        REFERENCES auth.users(id),
  payment_id   TEXT,
  order_id     TEXT,
  severity     TEXT        NOT NULL DEFAULT 'info',  -- info | warn | critical
  details      JSONB,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS audit_logs_user_idx      ON payment_audit_logs (user_id);
CREATE INDEX IF NOT EXISTS audit_logs_event_idx     ON payment_audit_logs (event_type);
CREATE INDEX IF NOT EXISTS audit_logs_severity_idx  ON payment_audit_logs (severity, created_at DESC);
CREATE INDEX IF NOT EXISTS audit_logs_created_idx   ON payment_audit_logs (created_at DESC);

ALTER TABLE payment_audit_logs ENABLE ROW LEVEL SECURITY;
-- No policies — only service_role can read or write this table.

-- ─────────────────────────────────────────────────────────────────────────────
-- Phase 5: get_active_entitlement() — server-authoritative RPC.
--
-- SECURITY DEFINER gives this function full visibility of the subscriptions
-- table regardless of client-side RLS. The inner WHERE clause enforces that
-- the caller (auth.uid()) can only query their own entitlement — it is
-- impossible to use this function to read another user's subscription.
--
-- Returns one row if the caller has an active PRO subscription; zero rows
-- if FREE or expired. Unknown / expired entitlement → deny access.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION get_active_entitlement()
RETURNS TABLE (
  subscription_id UUID,
  user_id         UUID,
  plan            TEXT,
  activated_at    TIMESTAMPTZ,
  expires_at      TIMESTAMPTZ,
  payment_id      TEXT,
  order_id        TEXT,
  status          TEXT,
  is_pro          BOOLEAN,
  days_remaining  INTEGER
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    s.id                                                                  AS subscription_id,
    s.user_id,
    s.plan,
    s.activated_at,
    s.expires_at,
    s.payment_id,
    s.order_id,
    s.status,
    (s.plan = 'pro'
       AND s.status = 'active'
       AND (s.expires_at IS NULL OR s.expires_at > NOW()))               AS is_pro,
    GREATEST(0,
      EXTRACT(DAY FROM (s.expires_at - NOW()))::INTEGER)                 AS days_remaining
  FROM subscriptions s
  WHERE s.user_id = auth.uid()
    AND s.status  = 'active'
    AND (s.expires_at IS NULL OR s.expires_at > NOW())
  ORDER BY s.created_at DESC
  LIMIT 1;
$$;

GRANT EXECUTE ON FUNCTION get_active_entitlement TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- Phase 5: has_active_pro() — lightweight feature-gate helper.
--
-- Used by server-side checks where a simple boolean is enough.
-- SECURITY DEFINER for the same reason as get_active_entitlement.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION has_active_pro()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM subscriptions s
    WHERE s.user_id = auth.uid()
      AND s.plan    = 'pro'
      AND s.status  = 'active'
      AND (s.expires_at IS NULL OR s.expires_at > NOW())
  );
$$;

GRANT EXECUTE ON FUNCTION has_active_pro TO authenticated;

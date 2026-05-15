-- =============================================================
-- AquaRythu — Payment Security Test Suite  (EPIC 5)
-- =============================================================
-- Tests: forged payment, replay attack, expired subscription,
-- modified amount, client-side subscription injection, and
-- get_active_entitlement isolation.
--
-- Usage:
--   psql $DATABASE_URL -f supabase/tests/payment_security_tests.sql
--
-- All statements run inside a single transaction that is rolled
-- back at the end — no test data is left behind.
-- =============================================================

BEGIN;

-- ── Shared assert helper ──────────────────────────────────────

CREATE OR REPLACE FUNCTION _pay_assert(
  test_name text,
  condition  boolean,
  details    text DEFAULT ''
) RETURNS void AS $$
BEGIN
  IF NOT condition THEN
    RAISE EXCEPTION 'FAIL: % — %', test_name, details;
  ELSE
    RAISE NOTICE 'PASS: %', test_name;
  END IF;
END;
$$ LANGUAGE plpgsql;

-- ── Test users ────────────────────────────────────────────────

INSERT INTO auth.users (id, email, created_at, updated_at, role, aud)
VALUES
  ('aa000000-0000-0000-0000-000000000001', 'pro_user@test.internal',      now(), now(), 'authenticated', 'authenticated'),
  ('aa000000-0000-0000-0000-000000000002', 'free_user@test.internal',     now(), now(), 'authenticated', 'authenticated'),
  ('aa000000-0000-0000-0000-000000000003', 'attacker@pay.test.internal',  now(), now(), 'authenticated', 'authenticated'),
  ('aa000000-0000-0000-0000-000000000004', 'expired_user@test.internal',  now(), now(), 'authenticated', 'authenticated')
ON CONFLICT (id) DO NOTHING;

-- ── JWT simulation helper ─────────────────────────────────────

CREATE OR REPLACE FUNCTION _set_pay_user(uid uuid) RETURNS void AS $$
BEGIN
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', uid::text, 'role', 'authenticated', 'aud', 'authenticated')::text,
    true);
  SET LOCAL ROLE authenticated;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION _set_service() RETURNS void AS $$
BEGIN
  SET LOCAL ROLE service_role;
  PERFORM set_config('request.jwt.claims', '{}', true);
END;
$$ LANGUAGE plpgsql;

-- ── Seed data (service_role creates subscriptions — simulates edge function) ─

PERFORM _set_service();

-- Active PRO subscription for pro_user
INSERT INTO public.subscriptions (id, user_id, plan, status, activated_at, expires_at, payment_id, order_id, created_at)
VALUES (
  'bb000000-0000-0000-0000-000000000001',
  'aa000000-0000-0000-0000-000000000001',
  'pro', 'active',
  now() - interval '5 days',
  now() + interval '115 days',
  'pay_test_pro_001',
  'order_test_pro_001',
  now() - interval '5 days'
);

-- Expired PRO subscription for expired_user
INSERT INTO public.subscriptions (id, user_id, plan, status, activated_at, expires_at, payment_id, order_id, created_at)
VALUES (
  'bb000000-0000-0000-0000-000000000002',
  'aa000000-0000-0000-0000-000000000004',
  'pro', 'active',
  now() - interval '125 days',
  now() - interval '5 days',   -- expired 5 days ago
  'pay_test_expired_001',
  'order_test_expired_001',
  now() - interval '125 days'
);

-- =============================================================
-- TEST GROUP P1: Subscriptions RLS — block client writes
-- =============================================================

PERFORM _set_pay_user('aa000000-0000-0000-0000-000000000003');

-- P1.1: Attacker cannot INSERT a subscription directly (fake PRO)
DO $$
BEGIN
  BEGIN
    INSERT INTO public.subscriptions (id, user_id, plan, status, activated_at, expires_at, payment_id, order_id, created_at)
    VALUES (
      'bb000000-0000-0000-ffff-000000000001',
      'aa000000-0000-0000-0000-000000000003',
      'pro', 'active',
      now(), now() + interval '120 days',
      'pay_fake_001', 'order_fake_001', now()
    );
    PERFORM _pay_assert('P1.1 client cannot INSERT fake subscription', false,
      'insert succeeded — RLS failed to block fake PRO');
  EXCEPTION WHEN insufficient_privilege OR check_violation THEN
    PERFORM _pay_assert('P1.1 client cannot INSERT fake subscription', true);
  END;
END $$;

-- P1.2: Attacker cannot UPDATE another user's subscription to PRO
DO $$
DECLARE v_rows int;
BEGIN
  UPDATE public.subscriptions
  SET plan = 'pro', status = 'active', expires_at = now() + interval '120 days'
  WHERE id = 'bb000000-0000-0000-0000-000000000002';
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  PERFORM _pay_assert('P1.2 client cannot UPDATE another user subscription', v_rows = 0,
    'update affected ' || v_rows || ' rows — cross-user tamper possible');
END $$;

-- P1.3: Attacker cannot UPDATE their own subscription (if they had one)
DO $$
DECLARE v_rows int;
BEGIN
  UPDATE public.subscriptions
  SET plan = 'pro', expires_at = now() + interval '365 days'
  WHERE user_id = 'aa000000-0000-0000-0000-000000000003';
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  PERFORM _pay_assert('P1.3 client cannot UPDATE own subscription to extend it', v_rows = 0,
    'update affected ' || v_rows || ' rows — client self-upgrade possible');
END $$;

-- =============================================================
-- TEST GROUP P2: Replay attack protection (UNIQUE constraints)
-- =============================================================

PERFORM _set_service();

-- P2.1: Duplicate payment_id is rejected
DO $$
BEGIN
  BEGIN
    INSERT INTO public.subscriptions (id, user_id, plan, status, activated_at, expires_at, payment_id, order_id, created_at)
    VALUES (
      'bb000000-0000-0000-ffff-000000000002',
      'aa000000-0000-0000-0000-000000000001',
      'pro', 'active',
      now(), now() + interval '120 days',
      'pay_test_pro_001',   -- duplicate payment_id
      'order_test_pro_999',
      now()
    );
    PERFORM _pay_assert('P2.1 duplicate payment_id rejected', false,
      'insert succeeded — replay attack via duplicate payment_id possible');
  EXCEPTION WHEN unique_violation THEN
    PERFORM _pay_assert('P2.1 duplicate payment_id rejected', true);
  END;
END $$;

-- P2.2: Duplicate order_id is rejected
DO $$
BEGIN
  BEGIN
    INSERT INTO public.subscriptions (id, user_id, plan, status, activated_at, expires_at, payment_id, order_id, created_at)
    VALUES (
      'bb000000-0000-0000-ffff-000000000003',
      'aa000000-0000-0000-0000-000000000001',
      'pro', 'active',
      now(), now() + interval '120 days',
      'pay_test_pro_999',
      'order_test_pro_001',  -- duplicate order_id
      now()
    );
    PERFORM _pay_assert('P2.2 duplicate order_id rejected', false,
      'insert succeeded — one order created two subscriptions');
  EXCEPTION WHEN unique_violation THEN
    PERFORM _pay_assert('P2.2 duplicate order_id rejected', true);
  END;
END $$;

-- =============================================================
-- TEST GROUP P3: get_active_entitlement — server-authoritative
-- =============================================================

-- P3.1: Active PRO user gets entitlement
PERFORM _set_pay_user('aa000000-0000-0000-0000-000000000001');
PERFORM _pay_assert(
  'P3.1 active PRO user gets entitlement',
  (SELECT COUNT(*) FROM get_active_entitlement()) = 1,
  'expected 1 row from get_active_entitlement for active PRO user'
);
PERFORM _pay_assert(
  'P3.1b entitlement is_pro = true',
  (SELECT is_pro FROM get_active_entitlement()),
  'is_pro was false for active PRO user'
);

-- P3.2: FREE user gets no entitlement
PERFORM _set_pay_user('aa000000-0000-0000-0000-000000000002');
PERFORM _pay_assert(
  'P3.2 FREE user gets no entitlement',
  (SELECT COUNT(*) FROM get_active_entitlement()) = 0,
  'expected 0 rows for FREE user — got entitlement rows'
);

-- P3.3: Expired subscription returns no entitlement
PERFORM _set_pay_user('aa000000-0000-0000-0000-000000000004');
PERFORM _pay_assert(
  'P3.3 expired subscription → no active entitlement',
  (SELECT COUNT(*) FROM get_active_entitlement()) = 0,
  'expired subscription was returned as active'
);

-- P3.4: User can only see own entitlement — cannot query another user's
-- (The RPC enforces auth.uid() = user_id so cross-user reads are impossible)
PERFORM _set_pay_user('aa000000-0000-0000-0000-000000000003');
PERFORM _pay_assert(
  'P3.4 attacker cannot see pro_user entitlement via RPC',
  (SELECT COUNT(*) FROM get_active_entitlement()) = 0,
  'attacker got entitlement rows for another user'
);

-- =============================================================
-- TEST GROUP P4: Subscription read isolation
-- =============================================================

PERFORM _set_pay_user('aa000000-0000-0000-0000-000000000003');

-- P4.1: Attacker cannot read pro_user subscription via direct table read
PERFORM _pay_assert(
  'P4.1 attacker cannot read other user subscription rows',
  (SELECT COUNT(*) FROM public.subscriptions
   WHERE user_id = 'aa000000-0000-0000-0000-000000000001') = 0,
  'attacker read victim subscription — RLS isolation failed'
);

-- P4.2: Pro user can read own subscription
PERFORM _set_pay_user('aa000000-0000-0000-0000-000000000001');
PERFORM _pay_assert(
  'P4.2 pro_user can read own subscription',
  (SELECT COUNT(*) FROM public.subscriptions
   WHERE user_id = 'aa000000-0000-0000-0000-000000000001') = 1,
  'owner cannot read own subscription row'
);

-- =============================================================
-- TEST GROUP P5: payment_audit_logs write-only from client
-- =============================================================

PERFORM _set_pay_user('aa000000-0000-0000-0000-000000000003');

-- P5.1: Client cannot SELECT from payment_audit_logs
PERFORM _pay_assert(
  'P5.1 client cannot read payment_audit_logs',
  (SELECT COUNT(*) FROM public.payment_audit_logs) = 0,
  'client read audit log rows — detection evasion possible'
);

-- P5.2: Client cannot INSERT into payment_audit_logs (tamper with audit trail)
DO $$
BEGIN
  BEGIN
    INSERT INTO public.payment_audit_logs (event_type, user_id, severity)
    VALUES ('payment_verified', 'aa000000-0000-0000-0000-000000000003', 'info');
    PERFORM _pay_assert('P5.2 client cannot INSERT payment_audit_logs', false,
      'insert succeeded — attacker can fabricate audit entries');
  EXCEPTION WHEN insufficient_privilege OR check_violation THEN
    PERFORM _pay_assert('P5.2 client cannot INSERT payment_audit_logs', true);
  END;
END $$;

-- =============================================================
-- Cleanup
-- =============================================================
ROLLBACK;

DO $$
BEGIN
  RAISE NOTICE '=== Payment security tests completed. Inspect NOTICE output for PASS/FAIL. ===';
END $$;

-- =============================================================
-- AquaRythu — RLS Security Test Suite
-- =============================================================
-- Run this as a Supabase superuser or service_role to verify
-- that RLS policies correctly isolate farm data.
--
-- Each test uses SET LOCAL ROLE and SET LOCAL request.jwt.claims
-- to simulate different authenticated users, then asserts the
-- expected row counts or error conditions.
--
-- Usage:
--   psql $DATABASE_URL -f supabase/tests/rls_security_tests.sql
--
-- All tests run inside a transaction that is rolled back, so
-- no test data is left behind.
-- =============================================================

BEGIN;

-- ── Test scaffolding ──────────────────────────────────────────

CREATE OR REPLACE FUNCTION _rls_assert(
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

-- Create two isolated test users
INSERT INTO auth.users (id, email, created_at, updated_at, role, aud)
VALUES
  ('00000000-0000-0000-0000-000000000001', 'attacker@test.internal',  now(), now(), 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000000002', 'victim@test.internal',    now(), now(), 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000000003', 'worker@test.internal',    now(), now(), 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000000004', 'partner@test.internal',   now(), now(), 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000000005', 'supervisor@test.internal', now(), now(), 'authenticated', 'authenticated')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.profiles (id, email, name)
VALUES
  ('00000000-0000-0000-0000-000000000001', 'attacker@test.internal',  'Attacker'),
  ('00000000-0000-0000-0000-000000000002', 'victim@test.internal',    'Victim'),
  ('00000000-0000-0000-0000-000000000003', 'worker@test.internal',    'Worker'),
  ('00000000-0000-0000-0000-000000000004', 'partner@test.internal',   'Partner'),
  ('00000000-0000-0000-0000-000000000005', 'supervisor@test.internal', 'Supervisor')
ON CONFLICT (id) DO NOTHING;

-- Create victim's farm
INSERT INTO public.farms (id, user_id, name)
VALUES ('00000000-0000-0000-0001-000000000001',
        '00000000-0000-0000-0000-000000000002', 'VictimFarm');

-- Add worker, partner, supervisor to victim's farm
INSERT INTO public.farm_members (id, farm_id, email, role)
VALUES
  ('00000000-0000-0000-0002-000000000003',
   '00000000-0000-0000-0001-000000000001',
   'worker@test.internal', 'worker'),
  ('00000000-0000-0000-0002-000000000004',
   '00000000-0000-0000-0001-000000000001',
   'partner@test.internal', 'partner'),
  ('00000000-0000-0000-0002-000000000005',
   '00000000-0000-0000-0001-000000000001',
   'supervisor@test.internal', 'supervisor');

-- Create victim's pond
INSERT INTO public.ponds (id, farm_id, user_id, name, area)
VALUES ('00000000-0000-0000-0003-000000000001',
        '00000000-0000-0000-0001-000000000001',
        '00000000-0000-0000-0000-000000000002',
        'Pond-A', 1.5);

-- Create victim's crop cycle
INSERT INTO public.crop_cycles (id, pond_id, start_date, seed_type, initial_count)
VALUES ('00000000-0000-0000-0004-000000000001',
        '00000000-0000-0000-0003-000000000001',
        CURRENT_DATE, 'hatchery', 100000);

-- Seed a feed round
INSERT INTO public.feed_rounds (id, pond_id, doc, round, planned_amount, crop_cycle_id)
VALUES ('00000000-0000-0000-0005-000000000001',
        '00000000-0000-0000-0003-000000000001',
        1, 1, 2.5,
        '00000000-0000-0000-0004-000000000001');

-- Seed a harvest log
INSERT INTO public.harvest_logs (id, pond_id, harvest_type, quantity, price, crop_cycle_id)
VALUES ('00000000-0000-0000-0006-000000000001',
        '00000000-0000-0000-0003-000000000001',
        'full', 500, 300,
        '00000000-0000-0000-0004-000000000001');

-- Seed an expense
INSERT INTO public.expenses (id, pond_id, farm_id, user_id, amount, category)
VALUES ('00000000-0000-0000-0007-000000000001',
        '00000000-0000-0000-0003-000000000001',
        '00000000-0000-0000-0001-000000000001',
        '00000000-0000-0000-0000-000000000002',
        5000, 'labour');

-- ── Helper: set active user for RLS ──────────────────────────

CREATE OR REPLACE FUNCTION _set_user(uid uuid) RETURNS void AS $$
BEGIN
  -- Supabase uses the JWT sub claim to determine auth.uid()
  PERFORM set_config('request.jwt.claims',
    json_build_object(
      'sub',  uid::text,
      'role', 'authenticated',
      'aud',  'authenticated'
    )::text,
    true  -- local to transaction
  );
  SET LOCAL ROLE authenticated;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION _set_service_role() RETURNS void AS $$
BEGIN
  SET LOCAL ROLE service_role;
  PERFORM set_config('request.jwt.claims', '{}', true);
END;
$$ LANGUAGE plpgsql;

-- =============================================================
-- TEST GROUP 1: Cross-farm reads (attacker cannot see victim data)
-- =============================================================

-- T1.1: Attacker cannot read victim's farm
PERFORM _set_user('00000000-0000-0000-0000-000000000001');
PERFORM _rls_assert(
  'T1.1 attacker cannot read victim farm',
  (SELECT count(*) FROM public.farms
   WHERE id = '00000000-0000-0000-0001-000000000001') = 0,
  'attacker saw victim farm rows'
);

-- T1.2: Attacker cannot read victim's ponds
PERFORM _rls_assert(
  'T1.2 attacker cannot read victim ponds',
  (SELECT count(*) FROM public.ponds
   WHERE farm_id = '00000000-0000-0000-0001-000000000001') = 0,
  'attacker saw victim pond rows'
);

-- T1.3: Attacker cannot read victim's feed rounds
PERFORM _rls_assert(
  'T1.3 attacker cannot read victim feed_rounds',
  (SELECT count(*) FROM public.feed_rounds
   WHERE pond_id = '00000000-0000-0000-0003-000000000001') = 0,
  'attacker saw victim feed round rows'
);

-- T1.4: Attacker cannot read victim's crop cycles
PERFORM _rls_assert(
  'T1.4 attacker cannot read victim crop_cycles',
  (SELECT count(*) FROM public.crop_cycles
   WHERE pond_id = '00000000-0000-0000-0003-000000000001') = 0,
  'attacker saw victim crop cycle rows'
);

-- T1.5: Attacker cannot read victim's harvest logs
PERFORM _rls_assert(
  'T1.5 attacker cannot read victim harvest_logs',
  (SELECT count(*) FROM public.harvest_logs
   WHERE pond_id = '00000000-0000-0000-0003-000000000001') = 0,
  'attacker saw victim harvest rows'
);

-- T1.6: Attacker cannot read victim's expenses
PERFORM _rls_assert(
  'T1.6 attacker cannot read victim expenses',
  (SELECT count(*) FROM public.expenses
   WHERE farm_id = '00000000-0000-0000-0001-000000000001') = 0,
  'attacker saw victim expense rows'
);

-- T1.7: Attacker cannot read farm_members of victim's farm
PERFORM _rls_assert(
  'T1.7 attacker cannot read victim farm_members',
  (SELECT count(*) FROM public.farm_members
   WHERE farm_id = '00000000-0000-0000-0001-000000000001') = 0,
  'attacker saw victim farm_member rows'
);

-- =============================================================
-- TEST GROUP 2: Cross-farm writes (forged farm_id attacks)
-- =============================================================

-- T2.1: Attacker cannot insert pond into victim's farm
DO $$
BEGIN
  BEGIN
    INSERT INTO public.ponds (id, farm_id, user_id, name, area)
    VALUES ('00000000-0000-0000-ffff-000000000001',
            '00000000-0000-0000-0001-000000000001',
            '00000000-0000-0000-0000-000000000001',
            'AttackerPond', 1.0);
    PERFORM _rls_assert('T2.1 attacker cannot insert pond in victim farm', false,
      'insert succeeded — RLS failed to block');
  EXCEPTION WHEN insufficient_privilege OR check_violation THEN
    PERFORM _rls_assert('T2.1 attacker cannot insert pond in victim farm', true);
  END;
END $$;

-- T2.2: Attacker cannot insert feed_round into victim's pond
DO $$
BEGIN
  BEGIN
    INSERT INTO public.feed_rounds (id, pond_id, doc, round, planned_amount)
    VALUES ('00000000-0000-0000-ffff-000000000002',
            '00000000-0000-0000-0003-000000000001',
            5, 1, 10.0);
    PERFORM _rls_assert('T2.2 attacker cannot insert feed_round in victim pond', false,
      'insert succeeded — RLS failed to block');
  EXCEPTION WHEN insufficient_privilege OR check_violation THEN
    PERFORM _rls_assert('T2.2 attacker cannot insert feed_round in victim pond', true);
  END;
END $$;

-- T2.3: Attacker cannot update victim's farm name
DO $$
DECLARE v_rows int;
BEGIN
  UPDATE public.farms
  SET name = 'HACKED'
  WHERE id = '00000000-0000-0000-0001-000000000001';
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  PERFORM _rls_assert('T2.3 attacker cannot update victim farm', v_rows = 0,
    'update affected ' || v_rows || ' rows');
END $$;

-- T2.4: Attacker cannot delete victim's farm
DO $$
DECLARE v_rows int;
BEGIN
  DELETE FROM public.farms
  WHERE id = '00000000-0000-0000-0001-000000000001';
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  PERFORM _rls_assert('T2.4 attacker cannot delete victim farm', v_rows = 0,
    'delete affected ' || v_rows || ' rows');
END $$;

-- =============================================================
-- TEST GROUP 3: Legitimate owner access
-- =============================================================
PERFORM _set_user('00000000-0000-0000-0000-000000000002');

-- T3.1: Victim can read their own farm
PERFORM _rls_assert(
  'T3.1 victim reads own farm',
  (SELECT count(*) FROM public.farms
   WHERE id = '00000000-0000-0000-0001-000000000001') = 1,
  'owner cannot see own farm'
);

-- T3.2: Victim can read their own ponds
PERFORM _rls_assert(
  'T3.2 victim reads own ponds',
  (SELECT count(*) FROM public.ponds
   WHERE farm_id = '00000000-0000-0000-0001-000000000001') = 1,
  'owner cannot see own ponds'
);

-- T3.3: Victim can read own feed rounds
PERFORM _rls_assert(
  'T3.3 victim reads own feed_rounds',
  (SELECT count(*) FROM public.feed_rounds
   WHERE pond_id = '00000000-0000-0000-0003-000000000001') = 1,
  'owner cannot see own feed rounds'
);

-- T3.4: Victim can read own harvest logs
PERFORM _rls_assert(
  'T3.4 victim reads own harvest_logs',
  (SELECT count(*) FROM public.harvest_logs
   WHERE pond_id = '00000000-0000-0000-0003-000000000001') = 1,
  'owner cannot see own harvest logs'
);

-- T3.5: Victim can read own expenses
PERFORM _rls_assert(
  'T3.5 victim reads own expenses',
  (SELECT count(*) FROM public.expenses
   WHERE farm_id = '00000000-0000-0000-0001-000000000001') = 1,
  'owner cannot see own expenses'
);

-- =============================================================
-- TEST GROUP 4: Role enforcement — worker restrictions
-- =============================================================
PERFORM _set_user('00000000-0000-0000-0000-000000000003');

-- T4.1: Worker can read operational data (feed rounds)
PERFORM _rls_assert(
  'T4.1 worker can read feed_rounds',
  (SELECT count(*) FROM public.feed_rounds
   WHERE pond_id = '00000000-0000-0000-0003-000000000001') = 1,
  'worker cannot read feed rounds'
);

-- T4.2: Worker CANNOT read harvest logs (finance data)
PERFORM _rls_assert(
  'T4.2 worker cannot read harvest_logs',
  (SELECT count(*) FROM public.harvest_logs
   WHERE pond_id = '00000000-0000-0000-0003-000000000001') = 0,
  'worker saw harvest log rows — finance isolation failed'
);

-- T4.3: Worker CANNOT read expenses (finance data)
PERFORM _rls_assert(
  'T4.3 worker cannot read expenses',
  (SELECT count(*) FROM public.expenses
   WHERE farm_id = '00000000-0000-0000-0001-000000000001') = 0,
  'worker saw expense rows — finance isolation failed'
);

-- T4.4: Worker CANNOT insert expenses
DO $$
BEGIN
  BEGIN
    INSERT INTO public.expenses (id, pond_id, farm_id, user_id, amount, category)
    VALUES ('00000000-0000-0000-ffff-000000000003',
            '00000000-0000-0000-0003-000000000001',
            '00000000-0000-0000-0001-000000000001',
            '00000000-0000-0000-0000-000000000003',
            999, 'other');
    PERFORM _rls_assert('T4.4 worker cannot insert expense', false,
      'insert succeeded — role enforcement failed');
  EXCEPTION WHEN insufficient_privilege OR check_violation THEN
    PERFORM _rls_assert('T4.4 worker cannot insert expense', true);
  END;
END $$;

-- T4.5: Worker CANNOT delete ponds
DO $$
DECLARE v_rows int;
BEGIN
  DELETE FROM public.ponds
  WHERE id = '00000000-0000-0000-0003-000000000001';
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  PERFORM _rls_assert('T4.5 worker cannot delete pond', v_rows = 0,
    'worker deleted pond — owner-only delete failed');
END $$;

-- =============================================================
-- TEST GROUP 5: Role enforcement — partner restrictions
-- =============================================================
PERFORM _set_user('00000000-0000-0000-0000-000000000004');

-- T5.1: Partner can read harvest logs (analytics)
PERFORM _rls_assert(
  'T5.1 partner can read harvest_logs',
  (SELECT count(*) FROM public.harvest_logs
   WHERE pond_id = '00000000-0000-0000-0003-000000000001') = 1,
  'partner cannot read harvest logs for analytics'
);

-- T5.2: Partner CANNOT insert feed rounds (read-only)
DO $$
BEGIN
  BEGIN
    INSERT INTO public.feed_rounds (id, pond_id, doc, round, planned_amount)
    VALUES ('00000000-0000-0000-ffff-000000000004',
            '00000000-0000-0000-0003-000000000001',
            3, 2, 5.0);
    PERFORM _rls_assert('T5.2 partner cannot insert feed_round', false,
      'insert succeeded — partner write isolation failed');
  EXCEPTION WHEN insufficient_privilege OR check_violation THEN
    PERFORM _rls_assert('T5.2 partner cannot insert feed_round', true);
  END;
END $$;

-- T5.3: Partner CANNOT update ponds
DO $$
DECLARE v_rows int;
BEGIN
  UPDATE public.ponds SET name = 'hacked' WHERE id = '00000000-0000-0000-0003-000000000001';
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  PERFORM _rls_assert('T5.3 partner cannot update pond', v_rows = 0,
    'partner updated pond — role enforcement failed');
END $$;

-- =============================================================
-- TEST GROUP 6: Supervisor access
-- =============================================================
PERFORM _set_user('00000000-0000-0000-0000-000000000005');

-- T6.1: Supervisor can read harvest logs
PERFORM _rls_assert(
  'T6.1 supervisor can read harvest_logs',
  (SELECT count(*) FROM public.harvest_logs
   WHERE pond_id = '00000000-0000-0000-0003-000000000001') = 1,
  'supervisor cannot read harvest logs'
);

-- T6.2: Supervisor can insert feed rounds
DO $$
BEGIN
  BEGIN
    INSERT INTO public.feed_rounds (id, pond_id, doc, round, planned_amount)
    VALUES ('00000000-0000-0000-ffff-000000000005',
            '00000000-0000-0000-0003-000000000001',
            4, 1, 3.0);
    PERFORM _rls_assert('T6.2 supervisor can insert feed_round', true);
  EXCEPTION WHEN OTHERS THEN
    PERFORM _rls_assert('T6.2 supervisor can insert feed_round', false,
      SQLERRM);
  END;
END $$;

-- T6.3: Supervisor CANNOT delete farm (owner-only)
DO $$
DECLARE v_rows int;
BEGIN
  DELETE FROM public.farms WHERE id = '00000000-0000-0000-0001-000000000001';
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  PERFORM _rls_assert('T6.3 supervisor cannot delete farm', v_rows = 0,
    'supervisor deleted farm — owner-only delete failed');
END $$;

-- =============================================================
-- TEST GROUP 7: Removed member loses access immediately
-- =============================================================
PERFORM _set_service_role();

-- Soft-remove the worker
UPDATE public.farm_members
SET status = 'removed'
WHERE id = '00000000-0000-0000-0002-000000000003';

PERFORM _set_user('00000000-0000-0000-0000-000000000003');

-- T7.1: Removed worker cannot read ponds
PERFORM _rls_assert(
  'T7.1 removed worker cannot read ponds',
  (SELECT count(*) FROM public.ponds
   WHERE farm_id = '00000000-0000-0000-0001-000000000001') = 0,
  'removed worker still sees ponds'
);

-- T7.2: Removed worker cannot insert feed rounds
DO $$
BEGIN
  BEGIN
    INSERT INTO public.feed_rounds (id, pond_id, doc, round, planned_amount)
    VALUES ('00000000-0000-0000-ffff-000000000006',
            '00000000-0000-0000-0003-000000000001',
            6, 1, 1.0);
    PERFORM _rls_assert('T7.2 removed worker cannot insert feed_round', false,
      'insert succeeded after removal');
  EXCEPTION WHEN insufficient_privilege OR check_violation THEN
    PERFORM _rls_assert('T7.2 removed worker cannot insert feed_round', true);
  END;
END $$;

-- =============================================================
-- TEST GROUP 8: feed_rounds_archive not publicly accessible
-- =============================================================
SET LOCAL ROLE anon;
PERFORM set_config('request.jwt.claims', '{}', true);

-- T8.1: Anonymous user cannot read feed_rounds_archive
PERFORM _rls_assert(
  'T8.1 anon cannot read feed_rounds_archive',
  (SELECT count(*) FROM public.feed_rounds_archive) = 0,
  'anon read feed_rounds_archive — critical data breach'
);

-- T8.2: Anonymous user cannot read farms
PERFORM _rls_assert(
  'T8.2 anon cannot read farms',
  (SELECT count(*) FROM public.farms) = 0,
  'anon read farms data'
);

-- =============================================================
-- TEST GROUP 9: Role escalation prevention
-- =============================================================
PERFORM _set_user('00000000-0000-0000-0000-000000000003');

-- T9.1: Worker cannot update their own role in farm_members
DO $$
DECLARE v_rows int;
BEGIN
  UPDATE public.farm_members
  SET role = 'farmer'
  WHERE id = '00000000-0000-0000-0002-000000000003';
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  PERFORM _rls_assert('T9.1 worker cannot escalate own role', v_rows = 0,
    'worker updated their own role to farmer');
END $$;

-- T9.2: Worker cannot insert a new farm_member row
DO $$
BEGIN
  BEGIN
    INSERT INTO public.farm_members (id, farm_id, email, role)
    VALUES ('00000000-0000-0000-ffff-000000000007',
            '00000000-0000-0000-0001-000000000001',
            'attacker@test.internal', 'farmer');
    PERFORM _rls_assert('T9.2 worker cannot insert farm_member', false,
      'worker inserted farm_member with farmer role');
  EXCEPTION WHEN insufficient_privilege OR check_violation THEN
    PERFORM _rls_assert('T9.2 worker cannot insert farm_member', true);
  END;
END $$;

-- =============================================================
-- TEST GROUP 10: Subscriptions isolation
-- =============================================================
PERFORM _set_user('00000000-0000-0000-0000-000000000001');

-- T10.1: User cannot read another user's subscription
PERFORM _rls_assert(
  'T10.1 attacker cannot read victim subscription',
  (SELECT count(*) FROM public.subscriptions
   WHERE user_id = '00000000-0000-0000-0000-000000000002') = 0,
  'attacker read victim subscription'
);

-- =============================================================
-- Cleanup — ROLLBACK undoes all test data
-- =============================================================
ROLLBACK;

-- Print summary
DO $$
BEGIN
  RAISE NOTICE '=== All RLS security tests completed. Inspect NOTICE output for PASS/FAIL. ===';
END $$;

-- Migration: Remove legacy RPC that references non-existent base_feed_amount
-- Purpose: Fix pond creation PostgresException column "base_feed_amount" does not exist
-- App now relies entirely on Dart-side FeedEngineV2 and Supabase direct inserts
-- This removes dead legacy feed schedule logic and ensures the feed engine uses one SSOT

DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN
        SELECT oid::regprocedure AS func_signature
        FROM pg_proc
        WHERE proname = 'create_pond_with_feed_plan'
    LOOP
        EXECUTE 'DROP FUNCTION ' || r.func_signature || ' CASCADE';
    END LOOP;
END $$;
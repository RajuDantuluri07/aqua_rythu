-- Migration: P0.6 Hardening - RPC Idempotency Guard + Server Timestamp
-- Purpose: Prevent duplicate completion with graceful idempotency
-- Enforces server timestamp to eliminate client clock risk

CREATE OR REPLACE FUNCTION complete_feed_round_with_log(
    p_pond_id UUID,
    p_doc INTEGER,
    p_round INTEGER,
    p_feed_amount DOUBLE PRECISION,
    p_base_feed DOUBLE PRECISION DEFAULT NULL,
    p_created_at TIMESTAMP WITH TIME ZONE DEFAULT NULL,
    p_tray_leftover DOUBLE PRECISION DEFAULT NULL,
    p_stocking_type TEXT DEFAULT NULL,
    p_density INTEGER DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
    feed_round_id UUID;
    existing_status TEXT;
    existing_log_count INTEGER;
    server_timestamp TIMESTAMP WITH TIME ZONE;
    feed_log_inserted BOOLEAN;
BEGIN
    -- ✅ ENFORCE: Server timestamp only (override client time)
    server_timestamp := NOW();

    -- Step 0: Fetch feed_round record
    SELECT id, status INTO feed_round_id, existing_status
    FROM feed_rounds
    WHERE pond_id = p_pond_id
    AND doc = p_doc
    AND round = p_round
    LIMIT 1;

    -- If round doesn't exist, fail fast
    IF feed_round_id IS NULL THEN
        RETURN json_build_object(
            'success', false,
            'alreadyCompleted', false,
            'logInserted', false,
            'error', 'Feed round not found for pond_id=' || p_pond_id || ', doc=' || p_doc || ', round=' || p_round
        );
    END IF;

    -- ✅ IDEMPOTENCY GUARD: Check if already has log entry
    SELECT COUNT(*) INTO existing_log_count
    FROM feed_logs
    WHERE feed_round_id = feed_round_id;

    -- If log already exists, return success (idempotent)
    IF existing_log_count > 0 THEN
        RAISE NOTICE 'Feed already logged for round_id=%', feed_round_id;
        RETURN json_build_object(
            'success', true,
            'alreadyCompleted', true,
            'logInserted', false,
            'message', 'Feed already logged for this round'
        );
    END IF;

    -- ✅ IDEMPOTENCY GUARD: Check if status already completed
    IF existing_status = 'completed' THEN
        RAISE NOTICE 'Feed round already marked completed: feed_round_id=%', feed_round_id;
        RETURN json_build_object(
            'success', true,
            'alreadyCompleted', true,
            'logInserted', false,
            'message', 'Feed round already completed'
        );
    END IF;

    -- Step 1: Update feed_round status to completed
    UPDATE feed_rounds
    SET status = 'completed',
        updated_at = server_timestamp
    WHERE id = feed_round_id;

    -- Step 2: Insert feed_log with SERVER timestamp
    INSERT INTO feed_logs (
        feed_round_id, pond_id, doc, round, feed_given, base_feed,
        created_at, tray_leftover, stocking_type, density
    ) VALUES (
        feed_round_id, p_pond_id, p_doc, p_round, p_feed_amount, p_base_feed,
        server_timestamp, p_tray_leftover, p_stocking_type, p_density
    );

    feed_log_inserted := TRUE;

    -- Atomic success
    RETURN json_build_object(
        'success', true,
        'alreadyCompleted', false,
        'logInserted', true,
        'roundId', feed_round_id,
        'message', 'Feed completion logged successfully'
    );

EXCEPTION
    WHEN unique_violation THEN
        -- UNIQUE constraint triggered (duplicate log attempt)
        RAISE NOTICE 'Feed already logged (UNIQUE violation): %', SQLERRM;
        RETURN json_build_object(
            'success', true,
            'alreadyCompleted', true,
            'logInserted', false,
            'message', 'Feed already logged (caught by UNIQUE constraint)'
        );
    WHEN OTHERS THEN
        RAISE NOTICE 'Feed transaction failed: %', SQLERRM;
        RETURN json_build_object(
            'success', false,
            'alreadyCompleted', false,
            'logInserted', false,
            'error', SQLERRM
        );
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION complete_feed_round_with_log IS
'Final hardening: Atomically complete feed round with strict guards.
- Enforces server timestamp (eliminates client clock risk)
- Idempotency check: existing log or completed status
- UNIQUE constraint catch-all
- Returns explicit JSON with all cases handled
- Safe for: retries, duplicate RPC calls, network issues';

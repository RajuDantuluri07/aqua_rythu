-- Migration: Enhance RPC to Return Structured Response
-- Purpose: Make RPC response explicit with details (success, alreadyCompleted, logInserted)
-- Enables Dart code to validate and handle all scenarios properly

CREATE OR REPLACE FUNCTION complete_feed_round_with_log(
    p_pond_id UUID,
    p_doc INTEGER,
    p_round INTEGER,
    p_feed_amount DOUBLE PRECISION,
    p_base_feed DOUBLE PRECISION DEFAULT NULL,
    p_created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    p_tray_leftover DOUBLE PRECISION DEFAULT NULL,
    p_stocking_type TEXT DEFAULT NULL,
    p_density INTEGER DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
    feed_round_id UUID;
    existing_status TEXT;
    feed_log_inserted BOOLEAN;
    is_already_completed BOOLEAN := FALSE;
BEGIN
    -- Step 0: Check if round is already completed (idempotency guard)
    SELECT id, status INTO feed_round_id, existing_status
    FROM feed_rounds
    WHERE pond_id = p_pond_id
    AND doc = p_doc
    AND round = p_round
    LIMIT 1;

    -- If already completed, return success with alreadyCompleted = true
    IF feed_round_id IS NOT NULL AND existing_status = 'completed' THEN
        RAISE NOTICE 'Feed round already completed: pond_id=%, doc=%, round=%', p_pond_id, p_doc, p_round;
        RETURN json_build_object(
            'success', true,
            'alreadyCompleted', true,
            'logInserted', false,
            'message', 'Feed round already completed - no action taken'
        );
    END IF;

    -- Step 1: Update or create feed_round record
    IF feed_round_id IS NOT NULL THEN
        -- Update existing feed_round to mark as completed
        UPDATE feed_rounds
        SET status = 'completed',
            updated_at = NOW()
        WHERE id = feed_round_id;
    ELSE
        -- Create new feed_round record with completed status
        INSERT INTO feed_rounds (
            pond_id, doc, round, planned_amount, base_feed, status
        ) VALUES (
            p_pond_id, p_doc, p_round, p_feed_amount, p_feed_amount, 'completed'
        ) RETURNING id INTO feed_round_id;
    END IF;

    -- Step 2: Insert feed_log using safe idempotent function
    -- This will not insert if entry already exists (ON CONFLICT DO NOTHING)
    SELECT safe_insert_feed_log(
        p_pond_id, p_doc, p_round, p_feed_amount, p_base_feed,
        p_created_at, p_tray_leftover, p_stocking_type, p_density
    ) INTO feed_log_inserted;

    -- Atomic success: feed_round.status updated AND (feed_log created OR already existed)
    RETURN json_build_object(
        'success', true,
        'alreadyCompleted', false,
        'logInserted', feed_log_inserted,
        'roundId', feed_round_id,
        'message', CASE 
            WHEN feed_log_inserted THEN 'Feed completion successful - log inserted'
            ELSE 'Feed completion successful - log already existed'
        END
    );

EXCEPTION
    WHEN OTHERS THEN
        -- Transaction will automatically rollback on any error
        RAISE NOTICE 'Feed transaction failed: %', SQLERRM;
        RETURN json_build_object(
            'success', false,
            'alreadyCompleted', false,
            'logInserted', false,
            'error', SQLERRM
        );
END;
$$ LANGUAGE plpgsql;

-- Update documentation
COMMENT ON FUNCTION complete_feed_round_with_log IS
'Atomically completes a feed round and logs the feed.
Returns JSON with: {success, alreadyCompleted, logInserted, message/error}
- success: true if operation completed or already done
- alreadyCompleted: true if was already completed (idempotent case)
- logInserted: true if feed_log was newly inserted
- Fully atomic: either both feed_rounds AND feed_logs updated, or neither (with rollback)
- Safe for retries: rapid clicks handled gracefully';

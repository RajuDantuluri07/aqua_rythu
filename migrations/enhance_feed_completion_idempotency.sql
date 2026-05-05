-- Migration: Enhance Feed Completion Idempotency
-- Purpose: Add safeguards against duplicate feed completion (rapid clicks)
-- Ensures that marking a feed as complete is truly idempotent

-- Update the complete_feed_round_with_log function to include idempotency check
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
RETURNS BOOLEAN AS $$
DECLARE
    feed_round_id UUID;
    existing_status TEXT;
    feed_log_inserted BOOLEAN;
BEGIN
    -- Step 0: Check if round is already completed (idempotency guard)
    SELECT id, status INTO feed_round_id, existing_status
    FROM feed_rounds
    WHERE pond_id = p_pond_id
    AND doc = p_doc
    AND round = p_round
    LIMIT 1;

    -- If already completed, return success (idempotent)
    IF feed_round_id IS NOT NULL AND existing_status = 'completed' THEN
        RAISE NOTICE 'Feed round already completed: pond_id=%, doc=%, round=%', p_pond_id, p_doc, p_round;
        RETURN TRUE;  -- Idempotent: return success as if we just completed it
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
    -- This handles duplicate entries gracefully with ON CONFLICT DO NOTHING
    SELECT safe_insert_feed_log(
        p_pond_id, p_doc, p_round, p_feed_amount, p_base_feed,
        p_created_at, p_tray_leftover, p_stocking_type, p_density
    ) INTO feed_log_inserted;

    -- If feed_log insertion failed (due to duplicate), still consider it success
    -- because the feed was already logged and the round was already marked complete
    IF NOT feed_log_inserted THEN
        -- This is NOT an error - the feed entry already exists
        RAISE NOTICE 'Feed log already exists for pond_id=%, doc=%, round=%', p_pond_id, p_doc, p_round;
    END IF;

    -- Atomic success: both feed_round.status updated AND feed_log exists
    RETURN TRUE;

EXCEPTION
    WHEN OTHERS THEN
        -- Transaction will automatically rollback on any error
        RAISE NOTICE 'Feed transaction failed: %', SQLERRM;
        RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- Update documentation
COMMENT ON FUNCTION complete_feed_round_with_log IS
'Atomically completes a feed round and logs the feed.
- Updates feed_rounds.status to completed
- Inserts entry in feed_logs (idempotent)
- Fully atomic: either all succeeds or all fails
- Idempotent: safe to call multiple times without side effects
- Returns TRUE on success or if already completed
- Returns FALSE only on actual errors (constraint violations, etc)';

-- Migration: Fix SQL Syntax Error in complete_feed_round_with_log RPC
-- Purpose: Fix ELSE { syntax error that was preventing the RPC from working
-- Impact: Ensures feed_rounds.status is properly updated to 'completed' when feed is logged

-- Drop the broken function
DROP FUNCTION IF EXISTS complete_feed_round_with_log(UUID, INTEGER, INTEGER, DOUBLE PRECISION, DOUBLE PRECISION, TIMESTAMP WITH TIME ZONE, DOUBLE PRECISION, TEXT, INTEGER);

-- Recreate with correct SQL syntax (ELSE instead of ELSE {)
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
    feed_log_inserted BOOLEAN;
BEGIN
    -- Step 1: Update or create feed_round record
    SELECT id INTO feed_round_id
    FROM feed_rounds
    WHERE pond_id = p_pond_id
    AND doc = p_doc
    AND round = p_round;

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
    SELECT safe_insert_feed_log(
        p_pond_id, p_doc, p_round, p_feed_amount, p_base_feed,
        p_created_at, p_tray_leftover, p_stocking_type, p_density
    ) INTO feed_log_inserted;

    -- If feed_log insertion failed (due to duplicate), rollback entire transaction
    IF NOT feed_log_inserted THEN
        RAISE EXCEPTION 'Feed log insertion failed - duplicate entry for pond_id=%, doc=%, round=%', p_pond_id, p_doc, p_round;
    END IF;

    RETURN TRUE;

EXCEPTION
    WHEN OTHERS THEN
        -- Transaction will automatically rollback on any error
        RAISE NOTICE 'Feed transaction failed: %', SQLERRM;
        RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- Add documentation comment
COMMENT ON FUNCTION complete_feed_round_with_log IS
'Atomically completes a feed round and logs the feed. Updates feed_rounds.status to completed and inserts entry in feed_logs. Ensures data consistency between feed_rounds and feed_logs tables.';

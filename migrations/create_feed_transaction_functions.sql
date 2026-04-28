-- Migration: Create Feed Transaction Functions
-- Purpose: Ensure atomic operations for feed_round update + feed_log insert
-- Business Rule: Either both operations succeed or both fail

-- Function to atomically complete feed round and log feed
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
    -- Start transaction
    -- Step 1: Update or create feed_round record
    SELECT id INTO feed_round_id
    FROM feed_rounds 
    WHERE pond_id = p_pond_id 
    AND doc = p_doc 
    AND round = p_round;
    
    IF feed_round_id IS NOT NULL THEN
        -- Update existing feed_round
        UPDATE feed_rounds 
        SET status = 'completed',
            updated_at = NOW()
        WHERE id = feed_round_id;
    ELSE {
        -- Create new feed_round record
        INSERT INTO feed_rounds (
            pond_id, doc, round, planned_amount, base_feed, status
        ) VALUES (
            p_pond_id, p_doc, p_round, p_feed_amount, p_feed_amount, 'completed'
        ) RETURNING id INTO feed_round_id;
    END IF;
    
    -- Step 2: Insert feed_log using safe function
    SELECT safe_insert_feed_log(
        p_pond_id, p_doc, p_round, p_feed_amount, p_base_feed,
        p_created_at, p_tray_leftover, p_stocking_type, p_density
    ) INTO feed_log_inserted;
    
    -- If feed_log insertion failed, rollback
    IF NOT feed_log_inserted THEN
        RAISE EXCEPTION 'Feed log insertion failed - duplicate entry';
    END IF;
    
    RETURN TRUE;
    
EXCEPTION
    WHEN OTHERS THEN
        -- Transaction will automatically rollback
        RAISE NOTICE 'Feed transaction failed: %', SQLERRM;
        RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- Function to safely update feed round amount with validation
CREATE OR REPLACE FUNCTION update_feed_round_amount(
    p_feed_round_id UUID,
    p_new_amount DOUBLE PRECISION,
    p_pond_id UUID DEFAULT NULL,
    p_doc INTEGER DEFAULT NULL,
    p_round INTEGER DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
    existing_record RECORD;
BEGIN
    -- Validate feed round exists
    SELECT * INTO existing_record
    FROM feed_rounds 
    WHERE id = p_feed_round_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Feed round not found: %', p_feed_round_id;
        RETURN FALSE;
    END IF;
    
    -- Validate amount is positive
    IF p_new_amount <= 0 THEN
        RAISE EXCEPTION 'Invalid feed amount: %', p_new_amount;
        RETURN FALSE;
    END IF;
    
    -- Update the feed round
    UPDATE feed_rounds 
    SET planned_amount = p_new_amount,
        base_feed = p_new_amount,
        is_manual = TRUE,
        updated_at = NOW()
    WHERE id = p_feed_round_id;
    
    RETURN TRUE;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Update feed round amount failed: %', SQLERRM;
        RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- Add comments for documentation
COMMENT ON FUNCTION complete_feed_round_with_log IS 
'Atomically completes a feed round and logs the feed. Ensures data consistency between feed_rounds and feed_logs tables';

COMMENT ON FUNCTION update_feed_round_amount IS 
'Safely updates feed round amount with validation. Returns TRUE on success, FALSE on failure';

-- Create indexes for performance if they don't exist
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_feed_rounds_pond_doc_round 
ON feed_rounds (pond_id, doc, round);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_feed_logs_pond_doc_round_created 
ON feed_logs (pond_id, doc, round, created_at);

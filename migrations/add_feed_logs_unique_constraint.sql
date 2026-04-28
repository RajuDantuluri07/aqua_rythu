-- Migration: Add Unique Constraint to feed_logs Table
-- Purpose: Prevent duplicate feed entries for same pond, DOC, and round
-- Business Rule: Each (pond_id, doc, round) combination must be unique

-- Add unique constraint to prevent duplicate feed entries
ALTER TABLE feed_logs 
ADD CONSTRAINT feed_logs_unique_pond_doc_round 
UNIQUE (pond_id, doc, round);

-- Add index for performance (unique constraint creates index automatically, but this ensures proper naming)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_feed_logs_pond_doc_round 
ON feed_logs (pond_id, doc, round);

-- Add comment documenting the constraint
COMMENT ON CONSTRAINT feed_logs_unique_pond_doc_round ON feed_logs IS 
'Prevents duplicate feed entries - each pond can only have one feed log per DOC and round combination';

-- Function to safely insert feed log with duplicate handling
CREATE OR REPLACE FUNCTION safe_insert_feed_log(
    p_pond_id UUID,
    p_doc INTEGER,
    p_round INTEGER,
    p_feed_given DOUBLE PRECISION,
    p_base_feed DOUBLE PRECISION DEFAULT NULL,
    p_created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    p_tray_leftover DOUBLE PRECISION DEFAULT NULL,
    p_stocking_type TEXT DEFAULT NULL,
    p_density INTEGER DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
    existing_count INTEGER;
BEGIN
    -- Check if entry already exists
    SELECT COUNT(*) INTO existing_count
    FROM feed_logs 
    WHERE pond_id = p_pond_id 
    AND doc = p_doc 
    AND round = p_round;
    
    -- If exists, skip insert and return FALSE
    IF existing_count > 0 THEN
        RETURN FALSE;
    END IF;
    
    -- Insert new record
    INSERT INTO feed_logs (
        pond_id, doc, round, feed_given, base_feed, created_at, 
        tray_leftover, stocking_type, density
    ) VALUES (
        p_pond_id, p_doc, p_round, p_feed_given, p_base_feed, p_created_at,
        p_tray_leftover, p_stocking_type, p_density
    );
    
    RETURN TRUE;
EXCEPTION
    WHEN unique_violation THEN
        -- Handle race condition - return FALSE instead of throwing error
        RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- Add comment for the function
COMMENT ON FUNCTION safe_insert_feed_log IS 
'Safely inserts feed log with duplicate protection. Returns TRUE if inserted, FALSE if skipped due to duplicate';

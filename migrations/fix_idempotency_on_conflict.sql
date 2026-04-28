-- Migration: Fix Idempotency using ON CONFLICT (DB Level Only)
-- Purpose: Replace pre-check logic with proper PostgreSQL ON CONFLICT handling

-- Drop the old safe_insert_feed_log function
DROP FUNCTION IF EXISTS safe_insert_feed_log CASCADE;

-- Create new idempotent insert function using ON CONFLICT
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
    inserted_count INTEGER;
BEGIN
    -- Use ON CONFLICT DO NOTHING for true idempotency at DB level
    INSERT INTO feed_logs (
        pond_id, doc, round, feed_given, base_feed, created_at, 
        tray_leftover, stocking_type, density
    ) VALUES (
        p_pond_id, p_doc, p_round, p_feed_given, p_base_feed, p_created_at,
        p_tray_leftover, p_stocking_type, p_density
    ) ON CONFLICT (pond_id, doc, round) DO NOTHING;
    
    -- Check if insert happened
    GET DIAGNOSTICS inserted_count = ROW_COUNT;
    RETURN inserted_count > 0;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Feed log insert failed: %', SQLERRM;
        RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- Update the transaction function to use the new idempotent insert
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
    
    -- Step 2: Insert feed_log using ON CONFLICT idempotent function
    SELECT safe_insert_feed_log(
        p_pond_id, p_doc, p_round, p_feed_amount, p_base_feed,
        p_created_at, p_tray_leftover, p_stocking_type, p_density
    ) INTO feed_log_inserted;
    
    -- If feed_log insertion failed (due to constraint), rollback
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

-- Add comment for documentation
COMMENT ON FUNCTION safe_insert_feed_log IS 
'Truly idempotent feed log insert using PostgreSQL ON CONFLICT DO NOTHING';

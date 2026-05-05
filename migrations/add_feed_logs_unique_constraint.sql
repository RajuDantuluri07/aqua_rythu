-- Migration: Add UNIQUE Constraint to feed_logs
-- Purpose: Prevent duplicate feed entries at database level (defense in depth)
-- Scope: One feed entry per (pond_id, doc, round) pair per day

-- Check if constraint already exists before adding
DO $$
BEGIN
    -- Try to add the unique constraint
    ALTER TABLE feed_logs
    ADD CONSTRAINT uq_feed_logs_pond_doc_round_date
    UNIQUE (pond_id, doc, round, DATE(created_at));
EXCEPTION
    WHEN duplicate_table THEN
        -- Constraint already exists, skip silently
        NULL;
    WHEN others THEN
        RAISE NOTICE 'Could not add unique constraint: %', SQLERRM;
END;
$$;

-- Add index for performance (overlaps with constraint, but explicit for query planning)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_feed_logs_unique_check
ON feed_logs (pond_id, doc, round, DATE(created_at));

-- Document the constraint
COMMENT ON CONSTRAINT uq_feed_logs_pond_doc_round_date ON feed_logs IS
'Prevents duplicate feed entries for the same pond, doc, round, and date.
Ensures one feed log per round per day. Acts as last line of defense against duplicate completion.';

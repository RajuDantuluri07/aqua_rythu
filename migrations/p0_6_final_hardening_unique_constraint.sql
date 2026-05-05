-- Migration: P0.6 Final Hardening - Strong UNIQUE Constraint
-- Purpose: Prevent duplicate feed_logs using feed_round_id (not date-based)
-- Eliminates timezone/clock mismatch issues

-- Step 1: Add feed_round_id column if it doesn't exist (track relationship)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'feed_logs' AND column_name = 'feed_round_id'
    ) THEN
        ALTER TABLE feed_logs ADD COLUMN feed_round_id UUID;
    END IF;
END $$;

-- Step 2: Add foreign key relationship
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE table_name = 'feed_logs' AND constraint_type = 'FOREIGN KEY'
        AND constraint_name = 'fk_feed_logs_feed_rounds'
    ) THEN
        ALTER TABLE feed_logs
        ADD CONSTRAINT fk_feed_logs_feed_rounds
        FOREIGN KEY (feed_round_id) REFERENCES feed_rounds(id) ON DELETE CASCADE;
    END IF;
END $$;

-- Step 3: Add STRICT UNIQUE constraint (one log per round)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE table_name = 'feed_logs' AND constraint_type = 'UNIQUE'
        AND constraint_name = 'uq_feed_logs_round'
    ) THEN
        ALTER TABLE feed_logs
        ADD CONSTRAINT uq_feed_logs_round UNIQUE (feed_round_id);
    END IF;
END $$;

-- Step 4: Replace old date-based constraint
DROP CONSTRAINT IF EXISTS uq_feed_logs_pond_doc_round_date ON feed_logs;

-- Step 5: Index for performance
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_feed_logs_feed_round_id
ON feed_logs (feed_round_id);

-- Documentation
COMMENT ON CONSTRAINT uq_feed_logs_round ON feed_logs IS
'STRICT UNIQUE: One feed_logs entry per feed_round.
Prevents duplicates regardless of timestamps, timezones, or clock skew.
Foreign key ensures referential integrity.';

COMMENT ON COLUMN feed_logs.feed_round_id IS
'Foreign key to feed_rounds. Ensures each round has exactly one completion log.';

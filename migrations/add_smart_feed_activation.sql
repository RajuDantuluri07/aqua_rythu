-- Migration: Add Smart Feed Activation to Ponds Table
-- Description: Adds is_smart_feed_enabled column to enable Smart Feed activation logic
-- Business Rule: Smart Feed activates ONLY when DOC > 30 and persists once activated

-- Add is_smart_feed_enabled column to ponds table
ALTER TABLE ponds 
ADD COLUMN is_smart_feed_enabled BOOLEAN DEFAULT FALSE;

-- Add index for performance (optional)
CREATE INDEX idx_ponds_smart_feed_enabled ON ponds(is_smart_feed_enabled);

-- Add comment for documentation
COMMENT ON COLUMN ponds.is_smart_feed_enabled IS 'Smart Feed activation status - TRUE when Smart Feed is activated (DOC > 30), FALSE otherwise. Once activated, never turns OFF.';

-- Create smart_feed_recommendations table for storing Smart Feed calculations
CREATE TABLE IF NOT EXISTS smart_feed_recommendations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pond_id UUID NOT NULL REFERENCES ponds(id) ON DELETE CASCADE,
    doc INTEGER NOT NULL,
    recommended_feed DECIMAL(10,2) NOT NULL,
    round_distribution DECIMAL(10,2)[] NOT NULL,
    alerts TEXT[] DEFAULT '{}',
    is_critical_stop BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add indexes for smart_feed_recommendations
CREATE INDEX idx_smart_feed_recommendations_pond_doc ON smart_feed_recommendations(pond_id, doc);
CREATE INDEX idx_smart_feed_recommendations_created_at ON smart_feed_recommendations(created_at);

-- Add comment for smart_feed_recommendations table
COMMENT ON TABLE smart_feed_recommendations IS 'Stores Smart Feed engine recommendations and calculations for analytics and troubleshooting';

-- Add is_smart_adjusted column to feed_plans table (for tracking Smart Feed adjustments)
ALTER TABLE feed_plans 
ADD COLUMN is_smart_adjusted BOOLEAN DEFAULT FALSE;

COMMENT ON COLUMN feed_plans.is_smart_adjusted IS 'TRUE if feed amount was adjusted by Smart Feed engine, FALSE if original planned amount';

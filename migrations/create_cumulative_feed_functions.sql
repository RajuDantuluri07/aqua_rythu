-- Migration: Create Cumulative Feed Calculation Functions
-- Purpose: Replace index-based cumulative calculation with DB SUM for accuracy
-- Business Rule: Cumulative feed should always be calculated from actual database records

-- Function to calculate cumulative feed up to a specific date
CREATE OR REPLACE FUNCTION calculate_cumulative_feed(
    p_pond_id UUID,
    p_target_date DATE DEFAULT CURRENT_DATE
)
RETURNS DOUBLE PRECISION AS $$
DECLARE
    cumulative_total DOUBLE PRECISION;
BEGIN
    SELECT COALESCE(SUM(feed_given), 0.0)
    INTO cumulative_total
    FROM feed_logs 
    WHERE pond_id = p_pond_id 
    AND DATE(created_at) <= p_target_date;
    
    RETURN cumulative_total;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Failed to calculate cumulative feed: %', SQLERRM;
        RETURN 0.0;
END;
$$ LANGUAGE plpgsql;

-- Function to get cumulative feed for all dates (for history loading)
CREATE OR REPLACE FUNCTION get_feed_history_with_cumulative(
    p_pond_id UUID,
    p_start_date DATE DEFAULT NULL,
    p_end_date DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE (
    feed_date DATE,
    feed_given DOUBLE PRECISION,
    base_feed DOUBLE PRECISION,
    doc INTEGER,
    cumulative DOUBLE PRECISION
) AS $$
BEGIN
    RETURN QUERY
    WITH daily_feed AS (
        SELECT 
            DATE(created_at) as feed_date,
            SUM(feed_given) as feed_given,
            COALESCE(MAX(base_feed), 0.0) as base_feed,
            MAX(doc) as doc
        FROM feed_logs 
        WHERE pond_id = p_pond_id
        AND (p_start_date IS NULL OR DATE(created_at) >= p_start_date)
        AND DATE(created_at) <= p_end_date
        GROUP BY DATE(created_at)
        ORDER BY feed_date ASC
    ),
    cumulative_feed AS (
        SELECT 
            feed_date,
            feed_given,
            base_feed,
            doc,
            SUM(feed_given) OVER (ORDER BY feed_date ASC ROWS UNBOUNDED PRECEDING) as cumulative
        FROM daily_feed
    )
    SELECT 
        cf.feed_date,
        cf.feed_given,
        cf.base_feed,
        cf.doc,
        cf.cumulative
    FROM cumulative_feed cf
    ORDER BY cf.feed_date ASC;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Failed to get feed history with cumulative: %', SQLERRM;
        RETURN EMPTY TABLE;
END;
$$ LANGUAGE plpgsql;

-- Function to safely get cumulative for a specific pond and date
CREATE OR REPLACE FUNCTION get_cumulative_feed_safe(
    p_pond_id UUID,
    p_date DATE DEFAULT CURRENT_DATE
)
RETURNS DOUBLE PRECISION AS $$
BEGIN
    RETURN calculate_cumulative_feed(p_pond_id, p_date);
EXCEPTION
    WHEN OTHERS THEN
        RETURN 0.0;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Add indexes for performance
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_feed_logs_pond_date 
ON feed_logs (pond_id, DATE(created_at));

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_feed_logs_created_at_date 
ON feed_logs (DATE(created_at));

-- Add comments for documentation
COMMENT ON FUNCTION calculate_cumulative_feed IS 
'Calculates total cumulative feed for a pond up to a specific date by summing all feed_logs records';

COMMENT ON FUNCTION get_feed_history_with_cumulative IS 
'Returns feed history with properly calculated cumulative totals using window functions';

COMMENT ON FUNCTION get_cumulative_feed_safe IS 
'Safe wrapper for cumulative feed calculation that returns 0 on error';

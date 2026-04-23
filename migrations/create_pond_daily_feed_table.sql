-- Create pond_daily_feed table for baseline + ROI system
-- This table tracks daily feed calculations, savings, and confidence levels

CREATE TABLE IF NOT EXISTS pond_daily_feed (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    pond_id UUID NOT NULL REFERENCES ponds(id) ON DELETE CASCADE,
    feed_date DATE NOT NULL,
    
    -- Feed calculation fields
    baseline_feed_kg FLOAT NOT NULL DEFAULT 0,
    actual_feed_kg FLOAT NOT NULL DEFAULT 0,
    feed_cost_per_kg FLOAT NOT NULL DEFAULT 60,
    
    -- ROI tracking fields
    daily_savings_rs FLOAT NOT NULL DEFAULT 0,
    cumulative_savings_rs FLOAT NOT NULL DEFAULT 0,
    
    -- Pond status fields
    abw FLOAT,
    biomass FLOAT,
    feed_rate FLOAT,
    
    -- Confidence and reasoning
    confidence_level TEXT NOT NULL DEFAULT 'low' CHECK (confidence_level IN ('high', 'medium', 'low')),
    reason TEXT NOT NULL DEFAULT '',
    
    -- Metadata
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Ensure one record per pond per day
    UNIQUE(pond_id, feed_date)
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_pond_daily_feed_pond_id ON pond_daily_feed(pond_id);
CREATE INDEX IF NOT EXISTS idx_pond_daily_feed_date ON pond_daily_feed(feed_date);
CREATE INDEX IF NOT EXISTS idx_pond_daily_feed_pond_date ON pond_daily_feed(pond_id, feed_date);
CREATE INDEX IF NOT EXISTS idx_pond_daily_feed_confidence ON pond_daily_feed(confidence_level);

-- Function to update cumulative savings when a new daily record is inserted
CREATE OR REPLACE FUNCTION update_cumulative_savings()
RETURNS TRIGGER AS $$
DECLARE
    previous_cumulative FLOAT;
BEGIN
    -- Get the previous cumulative savings for this pond
    SELECT COALESCE(MAX(cumulative_savings_rs), 0) INTO previous_cumulative
    FROM pond_daily_feed 
    WHERE pond_id = NEW.pond_id AND feed_date < NEW.feed_date;
    
    -- Update the new record's cumulative savings
    NEW.cumulative_savings_rs = previous_cumulative + NEW.daily_savings_rs;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to automatically update cumulative savings
CREATE TRIGGER trigger_update_cumulative_savings
    BEFORE INSERT ON pond_daily_feed
    FOR EACH ROW
    EXECUTE FUNCTION update_cumulative_savings();

-- Function to handle updates to daily savings (recalculate cumulative)
CREATE OR REPLACE FUNCTION recalculate_cumulative_on_update()
RETURNS TRIGGER AS $$
DECLARE
    days_diff INTEGER;
    later_records RECORD;
BEGIN
    -- Only recalculate if daily_savings changed
    IF OLD.daily_savings_rs IS DISTINCT FROM NEW.daily_savings_rs THEN
        -- Update cumulative for this record and all later records
        FOR later_records IN 
            SELECT id, feed_date 
            FROM pond_daily_feed 
            WHERE pond_id = NEW.pond_id 
            AND feed_date >= NEW.feed_date
            ORDER BY feed_date
        LOOP
            UPDATE pond_daily_feed 
            SET cumulative_savings_rs = (
                SELECT COALESCE(SUM(daily_savings_rs), 0)
                FROM pond_daily_feed 
                WHERE pond_id = NEW.pond_id 
                AND feed_date <= later_records.feed_date
            )
            WHERE id = later_records.id;
        END LOOP;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for updates
CREATE TRIGGER trigger_recalculate_cumulative_on_update
    AFTER UPDATE ON pond_daily_feed
    FOR EACH ROW
    EXECUTE FUNCTION recalculate_cumulative_on_update();

-- RLS (Row Level Security) policies
ALTER TABLE pond_daily_feed ENABLE ROW LEVEL SECURITY;

-- Allow read access to authenticated users for their own ponds
CREATE POLICY "Allow read access to own pond daily feed" ON pond_daily_feed
    FOR SELECT USING (
        auth.uid() IN (
            SELECT user_id FROM ponds WHERE id = pond_id
        )
    );

-- Allow insert access to authenticated users for their own ponds
CREATE POLICY "Allow insert to own pond daily feed" ON pond_daily_feed
    FOR INSERT WITH CHECK (
        auth.uid() IN (
            SELECT user_id FROM ponds WHERE id = pond_id
        )
    );

-- Allow update access to authenticated users for their own ponds
CREATE POLICY "Allow update to own pond daily feed" ON pond_daily_feed
    FOR UPDATE USING (
        auth.uid() IN (
            SELECT user_id FROM ponds WHERE id = pond_id
        )
    );

-- Allow service role full access (for backend processes)
CREATE POLICY "Allow full access to service role" ON pond_daily_feed
    FOR ALL USING (auth.role() = 'service_role');

-- Helper function to get daily feed summary for UI
CREATE OR REPLACE FUNCTION get_daily_feed_summary(pond_uuid UUID, target_date DATE DEFAULT CURRENT_DATE)
RETURNS JSONB AS $$
DECLARE
    result JSONB;
BEGIN
    SELECT jsonb_build_object(
        'baseline_feed', baseline_feed_kg,
        'actual_feed', actual_feed_kg,
        'daily_savings', daily_savings_rs,
        'total_savings', cumulative_savings_rs,
        'confidence', confidence_level,
        'reason', reason,
        'abw', abw,
        'biomass', biomass,
        'feed_rate', feed_rate,
        'feed_cost_per_kg', feed_cost_per_kg
    ) INTO result
    FROM pond_daily_feed 
    WHERE pond_id = pond_uuid AND feed_date = target_date;
    
    RETURN COALESCE(result, '{}'::jsonb);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

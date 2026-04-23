-- Add feed-related fields to pond_config table for baseline + ROI system
-- This migration ensures pond_config has all required fields for feed calculations

-- First, check if pond_config table exists, if not create it
CREATE TABLE IF NOT EXISTS pond_config (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    pond_id UUID NOT NULL REFERENCES ponds(id) ON DELETE CASCADE,
    
    -- Feed calculation configuration
    initial_shrimp_count INTEGER NOT NULL DEFAULT 0,
    survival_rate FLOAT NOT NULL DEFAULT 0.85,
    feed_cost_per_kg FLOAT NOT NULL DEFAULT 60.0,
    
    -- Additional configuration fields (for future use)
    target_fcr FLOAT DEFAULT 1.5,
    target_abw FLOAT DEFAULT 30.0,
    culture_duration_days INTEGER DEFAULT 120,
    
    -- Metadata
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Ensure one config per pond
    UNIQUE(pond_id)
);

-- Add columns if they don't exist (for existing pond_config table)
DO $$
BEGIN
    -- Add initial_shrimp_count if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pond_config' AND column_name = 'initial_shrimp_count'
    ) THEN
        ALTER TABLE pond_config ADD COLUMN initial_shrimp_count INTEGER NOT NULL DEFAULT 0;
    END IF;
    
    -- Add survival_rate if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pond_config' AND column_name = 'survival_rate'
    ) THEN
        ALTER TABLE pond_config ADD COLUMN survival_rate FLOAT NOT NULL DEFAULT 0.85;
    END IF;
    
    -- Add feed_cost_per_kg if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pond_config' AND column_name = 'feed_cost_per_kg'
    ) THEN
        ALTER TABLE pond_config ADD COLUMN feed_cost_per_kg FLOAT NOT NULL DEFAULT 60.0;
    END IF;
    
    -- Add optional target_fcr if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pond_config' AND column_name = 'target_fcr'
    ) THEN
        ALTER TABLE pond_config ADD COLUMN target_fcr FLOAT DEFAULT 1.5;
    END IF;
    
    -- Add optional target_abw if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pond_config' AND column_name = 'target_abw'
    ) THEN
        ALTER TABLE pond_config ADD COLUMN target_abw FLOAT DEFAULT 30.0;
    END IF;
    
    -- Add optional culture_duration_days if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pond_config' AND column_name = 'culture_duration_days'
    ) THEN
        ALTER TABLE pond_config ADD COLUMN culture_duration_days INTEGER DEFAULT 120;
    END IF;
END $$;

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_pond_config_pond_id ON pond_config(pond_id);

-- Create function to get or create pond config
CREATE OR REPLACE FUNCTION get_or_create_pond_config(pond_uuid UUID)
RETURNS TABLE (
    id UUID,
    initial_shrimp_count INTEGER,
    survival_rate FLOAT,
    feed_cost_per_kg FLOAT,
    target_fcr FLOAT,
    target_abw FLOAT,
    culture_duration_days INTEGER
) AS $$
BEGIN
    -- Try to return existing config
    RETURN QUERY
    SELECT 
        pc.id,
        pc.initial_shrimp_count,
        pc.survival_rate,
        pc.feed_cost_per_kg,
        pc.target_fcr,
        pc.target_abw,
        pc.culture_duration_days
    FROM pond_config pc
    WHERE pc.pond_id = pond_uuid;
    
    -- If no config found, create one with defaults from ponds table
    IF NOT FOUND THEN
        INSERT INTO pond_config (pond_id, initial_shrimp_count, survival_rate, feed_cost_per_kg)
        SELECT 
            p.id,
            p.seed_count,
            0.85, -- default survival rate
            60.0  -- default feed cost per kg
        FROM ponds p
        WHERE p.id = pond_uuid
        ON CONFLICT (pond_id) DO NOTHING;
        
        -- Return the newly created config
        RETURN QUERY
        SELECT 
            pc.id,
            pc.initial_shrimp_count,
            pc.survival_rate,
            pc.feed_cost_per_kg,
            pc.target_fcr,
            pc.target_abw,
            pc.culture_duration_days
        FROM pond_config pc
        WHERE pc.pond_id = pond_uuid;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RLS (Row Level Security) policies
ALTER TABLE pond_config ENABLE ROW LEVEL SECURITY;

-- Allow read access to authenticated users for their own ponds
CREATE POLICY "Allow read access to own pond config" ON pond_config
    FOR SELECT USING (
        auth.uid() IN (
            SELECT user_id FROM ponds WHERE id = pond_id
        )
    );

-- Allow insert access to authenticated users for their own ponds
CREATE POLICY "Allow insert to own pond config" ON pond_config
    FOR INSERT WITH CHECK (
        auth.uid() IN (
            SELECT user_id FROM ponds WHERE id = pond_id
        )
    );

-- Allow update access to authenticated users for their own ponds
CREATE POLICY "Allow update to own pond config" ON pond_config
    FOR UPDATE USING (
        auth.uid() IN (
            SELECT user_id FROM ponds WHERE id = pond_id
        )
    );

-- Allow service role full access (for backend processes)
CREATE POLICY "Allow full access to service role" ON pond_config
    FOR ALL USING (auth.role() = 'service_role');

-- Create trigger to update updated_at timestamp
CREATE TRIGGER update_pond_config_timestamp
    BEFORE UPDATE ON pond_config
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

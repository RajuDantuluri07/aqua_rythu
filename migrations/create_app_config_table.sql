-- Create app_config table for admin panel control
-- This table stores configuration that can be updated without app redeployment

CREATE TABLE IF NOT EXISTS app_config (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    key TEXT UNIQUE NOT NULL,
    value JSONB NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_app_config_key ON app_config(key);

-- Insert default configuration values
INSERT INTO app_config (key, value) VALUES 
('feed_engine', '{
    "smart_feed_enabled": true,
    "blind_feed_doc_limit": 30,
    "global_feed_multiplier": 1.0,
    "feed_kill_switch": false
}'),
('pricing', '{
    "feed_price_per_kg": 120
}'),
('features', '{
    "feature_smart_feed": true,
    "feature_sampling": true,
    "feature_growth": false,
    "feature_profit": false
}'),
('announcement', '{
    "banner_enabled": false,
    "banner_message": ""
}'),
('debug', '{
    "debug_mode_enabled": false
}')
ON CONFLICT (key) DO NOTHING;

-- RLS (Row Level Security) policies
-- Allow read access to all authenticated users (app needs to read config)
ALTER TABLE app_config ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow read access to authenticated users" ON app_config
    FOR SELECT USING (auth.role() = 'authenticated');

-- Allow write access only to service role or specific admin users
-- This will be handled by service key in the admin service
CREATE POLICY "Allow write access to service role" ON app_config
    FOR ALL USING (auth.role() = 'service_role');

-- Create function to get config value with fallback
CREATE OR REPLACE FUNCTION get_config_value(config_key TEXT, default_value JSONB)
RETURNS JSONB AS $$
BEGIN
    RETURN COALESCE(
        (SELECT value FROM app_config WHERE key = config_key LIMIT 1),
        default_value
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Add version column to app_config table
ALTER TABLE app_config ADD COLUMN IF NOT EXISTS version INT DEFAULT 1;

-- Create index for version queries
CREATE INDEX IF NOT EXISTS idx_app_config_key_version ON app_config(key, version);

-- Add constraint to ensure version is positive
ALTER TABLE app_config ADD CONSTRAINT IF NOT EXISTS check_version_positive CHECK (version >= 1);

-- Create trigger to automatically increment version on updates
CREATE OR REPLACE FUNCTION increment_config_version()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'UPDATE' THEN
        NEW.version = OLD.version + 1;
        NEW.updated_at = NOW();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for app_config table
DROP TRIGGER IF EXISTS trigger_increment_config_version ON app_config;
CREATE TRIGGER trigger_increment_config_version
    BEFORE UPDATE ON app_config
    FOR EACH ROW
    EXECUTE FUNCTION increment_config_version();

-- Ensure all existing records have version = 1
UPDATE app_config SET version = 1 WHERE version IS NULL;

-- Add unique constraint on key to prevent duplicate config keys
ALTER TABLE app_config ADD CONSTRAINT IF NOT EXISTS unique_config_key UNIQUE (key);

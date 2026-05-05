-- Remove schedule dependency from feed logging
ALTER TABLE feed_logs DROP COLUMN IF EXISTS feed_round_id;

-- Ensure required independent logging fields exist
ALTER TABLE feed_logs
ADD COLUMN IF NOT EXISTS pond_id TEXT,
ADD COLUMN IF NOT EXISTS doc INT,
ADD COLUMN IF NOT EXISTS feed_kg FLOAT,
ADD COLUMN IF NOT EXISTS round INT,
ADD COLUMN IF NOT EXISTS source TEXT,
ADD COLUMN IF NOT EXISTS created_at TIMESTAMP DEFAULT now();

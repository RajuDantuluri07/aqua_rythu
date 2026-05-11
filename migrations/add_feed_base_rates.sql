-- Migration: Add feed_base_rates table for configurable feed rates
-- This allows farmers to customize feed rates per seed type and DOC

CREATE TABLE feed_base_rates (
  id SERIAL PRIMARY KEY,
  seed_type VARCHAR(20) NOT NULL CHECK (seed_type IN ('hatchery', 'nursery')),
  doc INTEGER NOT NULL CHECK (doc >= 1),
  feed_kg_per_100k DECIMAL(10,2) NOT NULL CHECK (feed_kg_per_100k > 0),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(seed_type, doc)
);

-- Insert default rates for hatchery (calculated from incremental formula)
INSERT INTO feed_base_rates (seed_type, doc, feed_kg_per_100k) VALUES
('hatchery', 1, 1.5),
('hatchery', 2, 1.7),
('hatchery', 3, 1.9),
('hatchery', 4, 2.1),
('hatchery', 5, 2.3),
('hatchery', 6, 2.5),
('hatchery', 7, 2.7),
('hatchery', 8, 3.0),
('hatchery', 9, 3.3),
('hatchery', 10, 3.6),
('hatchery', 11, 3.9),
('hatchery', 12, 4.2),
('hatchery', 13, 4.5),
('hatchery', 14, 4.8),
('hatchery', 15, 5.2),
('hatchery', 16, 5.6),
('hatchery', 17, 6.0),
('hatchery', 18, 6.4),
('hatchery', 19, 6.8),
('hatchery', 20, 7.2),
('hatchery', 21, 7.6),
('hatchery', 22, 8.1),
('hatchery', 23, 8.6),
('hatchery', 24, 9.1),
('hatchery', 25, 9.6),
('hatchery', 26, 10.1),
('hatchery', 27, 10.6),
('hatchery', 28, 11.1),
('hatchery', 29, 11.6),
('hatchery', 30, 12.1);

-- Insert default rates for nursery (user-specified values)
INSERT INTO feed_base_rates (seed_type, doc, feed_kg_per_100k) VALUES
('nursery', 1, 4.0),
('nursery', 2, 5.0),
('nursery', 3, 6.0),
('nursery', 4, 7.0),
('nursery', 5, 8.0),
('nursery', 6, 9.0),
('nursery', 7, 10.0),
('nursery', 8, 11.0),
('nursery', 9, 12.0),
('nursery', 10, 13.0),
('nursery', 11, 13.0),
('nursery', 12, 13.0),
('nursery', 13, 13.0),
('nursery', 14, 13.0),
('nursery', 15, 13.0),
('nursery', 16, 13.0),
('nursery', 17, 13.0),
('nursery', 18, 13.0),
('nursery', 19, 13.0),
('nursery', 20, 13.0);

-- Add index for performance
CREATE INDEX idx_feed_base_rates_seed_type_doc ON feed_base_rates(seed_type, doc);

-- Add trigger to update updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_feed_base_rates_updated_at
    BEFORE UPDATE ON feed_base_rates
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
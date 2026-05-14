-- Add feed_brand_id column to ponds table for feed company selection
ALTER TABLE ponds ADD COLUMN feed_brand_id TEXT REFERENCES feed_master_products(id) ON DELETE SET NULL;

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_ponds_feed_brand_id ON ponds(feed_brand_id);

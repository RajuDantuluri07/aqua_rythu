-- Migration: Add feed tracking columns to feeding_logs
-- Purpose: Enable inventory integration with feeding system
-- Adds feed_quantity and feed_type for automatic inventory deduction
-- Run in Supabase SQL Editor

ALTER TABLE feeding_logs 
ADD COLUMN IF NOT EXISTS feed_quantity NUMERIC,
ADD COLUMN IF NOT EXISTS feed_type TEXT;

-- Add comments for documentation
COMMENT ON COLUMN feeding_logs.feed_quantity IS 'Feed quantity used for inventory auto-deduction';
COMMENT ON COLUMN feeding_logs.feed_type IS 'Type of feed used (maps to inventory_items.category)';

-- Create index for performance
CREATE INDEX IF NOT EXISTS idx_feeding_logs_feed_quantity ON feeding_logs(feed_quantity);
CREATE INDEX IF NOT EXISTS idx_feeding_logs_feed_type ON feeding_logs(feed_type);

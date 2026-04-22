-- Migration: Create trigger for automatic feed inventory deduction
-- Purpose: Fire handle_feed_inventory function after feeding_logs insert
-- Enables zero-manual inventory tracking for feed items
-- Run in Supabase SQL Editor

-- Drop trigger if it exists to avoid conflicts
DROP TRIGGER IF EXISTS trg_feed_inventory ON feeding_logs;

-- Create trigger
CREATE TRIGGER trg_feed_inventory
AFTER INSERT ON feeding_logs
FOR EACH ROW
EXECUTE FUNCTION handle_feed_inventory();

-- Add comment for documentation
COMMENT ON TRIGGER trg_feed_inventory ON feeding_logs IS 'Automatically deducts feed inventory on feeding log creation';

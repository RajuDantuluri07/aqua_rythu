-- Migration: Add base_feed column to feed_logs
-- Purpose: Store engine-calculated feed recommendations for each logged feeding
-- This enables tracking of actual vs. recommended feed for optimization
-- Run in Supabase SQL Editor

ALTER TABLE feed_logs ADD COLUMN base_feed DOUBLE PRECISION DEFAULT NULL;

-- Add comment documenting the column
COMMENT ON COLUMN feed_logs.base_feed IS 'Engine-calculated base feed recommendation (kg) from orchestrator result';

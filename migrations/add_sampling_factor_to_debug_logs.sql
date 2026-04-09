-- Migration: add sampling_factor, abw, expected_abw to feed_debug_logs
-- Run this in Supabase SQL editor before deploying the app update.

ALTER TABLE feed_debug_logs
  ADD COLUMN IF NOT EXISTS sampling_factor FLOAT DEFAULT 1.0,
  ADD COLUMN IF NOT EXISTS abw             FLOAT,
  ADD COLUMN IF NOT EXISTS expected_abw    FLOAT;

COMMENT ON COLUMN feed_debug_logs.sampling_factor IS 'Optional growth-sample correction factor. Clamped [0.9, 1.1]. 1.0 when no fresh sample available.';
COMMENT ON COLUMN feed_debug_logs.abw             IS 'Latest actual body weight (g) used for sampling factor, null if no fresh sample within 7 days.';
COMMENT ON COLUMN feed_debug_logs.expected_abw    IS 'Expected ABW (g) for this DOC from the static lookup table.';

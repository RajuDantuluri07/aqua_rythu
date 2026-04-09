-- Migration: add latest_sample_date to ponds table
-- Enables the feed engine to check ABW freshness without a separate
-- sampling_logs query on every feed calculation.
--
-- Run this in Supabase SQL editor BEFORE deploying the app update.

ALTER TABLE ponds
  ADD COLUMN IF NOT EXISTS latest_sample_date TIMESTAMPTZ;

COMMENT ON COLUMN ponds.latest_sample_date IS
  'Timestamp of the most recent growth sample. Used by the feed engine '
  'to determine if current_abw is fresh (≤ 7 days) without an extra DB query.';

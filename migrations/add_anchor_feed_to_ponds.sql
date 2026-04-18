-- Migration: Add Anchor Feed to Ponds Table
-- Business Rule: For DOC > 30, the farmer's manually entered feed amount serves
-- as the anchor baseline. Tray response adjusts it ±30% each round.

ALTER TABLE ponds
ADD COLUMN IF NOT EXISTS anchor_feed FLOAT;

ALTER TABLE ponds
ADD COLUMN IF NOT EXISTS is_anchor_initialized BOOLEAN DEFAULT FALSE;

-- Migration: Add pack-based tracking to inventory
-- Purpose: Layer farmer-friendly pack UX on top of existing quantity-based schema
-- Items now know their pack_size (e.g., 25 kg/bag), cost_per_pack, and pack_label.
-- Purchases snapshot the packs bought + pack_size_at_purchase for cost history.
-- pack_size NULL = raw quantity tracking (legacy, still supported).
-- Run in Supabase SQL Editor.

-- 1. inventory_items: add pack metadata
ALTER TABLE inventory_items
    ADD COLUMN IF NOT EXISTS pack_size NUMERIC,
    ADD COLUMN IF NOT EXISTS cost_per_pack NUMERIC,
    ADD COLUMN IF NOT EXISTS pack_label TEXT DEFAULT 'pack';

COMMENT ON COLUMN inventory_items.pack_size IS 'Quantity per pack in inventory unit (e.g., 25 kg/bag). NULL = raw tracking.';
COMMENT ON COLUMN inventory_items.cost_per_pack IS 'Cost per whole pack (e.g., ₹2200 per 25kg bag).';
COMMENT ON COLUMN inventory_items.pack_label IS 'Display label for one pack: bag, bottle, jar, etc.';

-- Sanity: pack_size must be positive when set
ALTER TABLE inventory_items
    DROP CONSTRAINT IF EXISTS pack_size_positive;
ALTER TABLE inventory_items
    ADD CONSTRAINT pack_size_positive CHECK (pack_size IS NULL OR pack_size > 0);

-- 2. inventory_purchases: snapshot pack info at purchase time
ALTER TABLE inventory_purchases
    ADD COLUMN IF NOT EXISTS packs NUMERIC,
    ADD COLUMN IF NOT EXISTS pack_size_at_purchase NUMERIC,
    ADD COLUMN IF NOT EXISTS cost_per_pack NUMERIC;

COMMENT ON COLUMN inventory_purchases.packs IS 'Number of packs purchased (e.g., 8 bags). NULL for raw purchases.';
COMMENT ON COLUMN inventory_purchases.pack_size_at_purchase IS 'Pack size when purchased — preserves history if pack_size later changes.';
COMMENT ON COLUMN inventory_purchases.cost_per_pack IS 'Cost per pack at purchase time.';

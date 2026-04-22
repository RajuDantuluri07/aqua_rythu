-- Migration: Create handle_feed_inventory function
-- Purpose: Automatically deduct feed from inventory when feeding logs are created
-- Trigger function that links feeding to inventory consumption
-- Run in Supabase SQL Editor

CREATE OR REPLACE FUNCTION handle_feed_inventory()
RETURNS TRIGGER AS $$
DECLARE
    feed_item_id UUID;
BEGIN
    -- Find the feed inventory item for this crop
    SELECT id INTO feed_item_id
    FROM inventory_items
    WHERE crop_id = NEW.crop_id
      AND category = 'feed'
      AND is_auto_tracked = TRUE
    LIMIT 1;

    -- Only proceed if we found a feed inventory item
    IF feed_item_id IS NOT NULL THEN
        -- Insert consumption record
        INSERT INTO inventory_consumption (
            item_id,
            quantity_used,
            source,
            reference_id,
            date
        ) VALUES (
            feed_item_id,
            COALESCE(NEW.feed_quantity, NEW.feed_given, 0),
            'feed_auto',
            NEW.id,
            NEW.date::DATE
        );
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Add comment for documentation
COMMENT ON FUNCTION handle_feed_inventory() IS 'Auto-deducts feed inventory when feeding logs are created';

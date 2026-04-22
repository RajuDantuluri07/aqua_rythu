-- Migration: Create functions for handling feed inventory updates
-- Purpose: Handle inventory consumption when feed logs are updated or deleted
-- Ensures inventory stays in sync with feed changes
-- Run in Supabase SQL Editor

-- Function to handle feed log updates
CREATE OR REPLACE FUNCTION handle_feed_inventory_update()
RETURNS TRIGGER AS $$
DECLARE
    feed_item_id UUID;
    old_quantity_used NUMERIC;
    new_quantity_used NUMERIC;
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
        old_quantity_used := COALESCE(OLD.feed_quantity, OLD.feed_given, 0);
        new_quantity_used := COALESCE(NEW.feed_quantity, NEW.feed_given, 0);
        
        -- If quantities are different, adjust consumption
        IF old_quantity_used != new_quantity_used THEN
            -- Remove old consumption and add new one
            DELETE FROM inventory_consumption
            WHERE item_id = feed_item_id
              AND reference_id = NEW.id
              AND source = 'feed_auto';
            
            -- Add new consumption record
            INSERT INTO inventory_consumption (
                item_id,
                quantity_used,
                source,
                reference_id,
                date
            ) VALUES (
                feed_item_id,
                new_quantity_used,
                'feed_auto',
                NEW.id,
                NEW.date::DATE
            );
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to handle feed log deletions
CREATE OR REPLACE FUNCTION handle_feed_inventory_delete()
RETURNS TRIGGER AS $$
DECLARE
    feed_item_id UUID;
BEGIN
    -- Find the feed inventory item for this crop
    SELECT id INTO feed_item_id
    FROM inventory_items
    WHERE crop_id = OLD.crop_id
      AND category = 'feed'
      AND is_auto_tracked = TRUE
    LIMIT 1;

    -- Only proceed if we found a feed inventory item
    IF feed_item_id IS NOT NULL THEN
        -- Remove the consumption record
        DELETE FROM inventory_consumption
        WHERE item_id = feed_item_id
          AND reference_id = OLD.id
          AND source = 'feed_auto';
    END IF;

    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- Create update trigger
DROP TRIGGER IF EXISTS trg_feed_inventory_update ON feeding_logs;
CREATE TRIGGER trg_feed_inventory_update
AFTER UPDATE ON feeding_logs
FOR EACH ROW
EXECUTE FUNCTION handle_feed_inventory_update();

-- Create delete trigger
DROP TRIGGER IF EXISTS trg_feed_inventory_delete ON feeding_logs;
CREATE TRIGGER trg_feed_inventory_delete
AFTER DELETE ON feeding_logs
FOR EACH ROW
EXECUTE FUNCTION handle_feed_inventory_delete();

-- Add comments for documentation
COMMENT ON FUNCTION handle_feed_inventory_update() IS 'Adjusts inventory consumption when feed logs are updated';
COMMENT ON FUNCTION handle_feed_inventory_delete() IS 'Removes inventory consumption when feed logs are deleted';
COMMENT ON TRIGGER trg_feed_inventory_update ON feeding_logs IS 'Updates inventory consumption on feed log changes';
COMMENT ON TRIGGER trg_feed_inventory_delete ON feeding_logs IS 'Removes inventory consumption on feed log deletion';

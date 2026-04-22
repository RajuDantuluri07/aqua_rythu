-- Migration: Create inventory_consumption table
-- Purpose: Track all inventory usage/consumption events
-- Auto-populated for feed items via trigger, manual for others
-- Run in Supabase SQL Editor

CREATE TABLE IF NOT EXISTS inventory_consumption (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    item_id UUID NOT NULL REFERENCES inventory_items(id) ON DELETE CASCADE,
    
    quantity_used NUMERIC NOT NULL,
    source TEXT NOT NULL, -- 'feed_auto', 'manual', 'waste', 'theft', etc.
    reference_id UUID, -- Links to feed_logs.id for auto tracking
    
    date DATE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add indexes for performance
CREATE INDEX idx_inventory_consumption_item_id ON inventory_consumption(item_id);
CREATE INDEX idx_inventory_consumption_date ON inventory_consumption(date);
CREATE INDEX idx_inventory_consumption_source ON inventory_consumption(source);
CREATE INDEX idx_inventory_consumption_reference ON inventory_consumption(reference_id);

-- Add comments for documentation
COMMENT ON TABLE inventory_consumption IS 'Tracks all inventory usage and consumption events';
COMMENT ON COLUMN inventory_consumption.quantity_used IS 'Amount consumed from inventory';
COMMENT ON COLUMN inventory_consumption.source IS 'Source of consumption: feed_auto, manual, waste, etc.';
COMMENT ON COLUMN inventory_consumption.reference_id IS 'Links to feed_logs.id for automatic feed tracking';

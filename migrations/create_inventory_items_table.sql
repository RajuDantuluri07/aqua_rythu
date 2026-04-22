-- Migration: Create inventory_items table
-- Purpose: Core inventory system for tracking stock items
-- Supports zero-manual inventory with auto-tracking for feed items
-- Run in Supabase SQL Editor

CREATE TABLE IF NOT EXISTS inventory_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    farm_id UUID,
    crop_id UUID, -- Links to pond/crop for feed auto-tracking
    
    name TEXT NOT NULL,
    category TEXT NOT NULL, -- 'feed', 'medicine', 'equipment', etc.
    unit TEXT NOT NULL, -- 'kg', 'liters', 'pieces', etc.
    
    opening_quantity NUMERIC DEFAULT 0,
    price_per_unit NUMERIC,
    
    is_auto_tracked BOOLEAN DEFAULT FALSE, -- Only TRUE for feed items
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add indexes for performance
CREATE INDEX idx_inventory_items_user_id ON inventory_items(user_id);
CREATE INDEX idx_inventory_items_farm_id ON inventory_items(farm_id);
CREATE INDEX idx_inventory_items_crop_id ON inventory_items(crop_id);
CREATE INDEX idx_inventory_items_category ON inventory_items(category);

-- Add constraint: Only one feed item per crop
ALTER TABLE inventory_items ADD CONSTRAINT unique_feed_per_crop 
    EXCLUDE (crop_id WITH =) WHERE (category = 'feed' AND is_auto_tracked = TRUE);

-- Add comments for documentation
COMMENT ON TABLE inventory_items IS 'Core inventory tracking table for all stock items';
COMMENT ON COLUMN inventory_items.category IS 'Item category: feed, medicine, equipment, etc.';
COMMENT ON COLUMN inventory_items.is_auto_tracked IS 'TRUE only for feed items - enables auto-deduction';
COMMENT ON COLUMN inventory_items.opening_quantity IS 'Initial stock quantity at setup';
COMMENT ON COLUMN inventory_items.price_per_unit IS 'Cost per unit for valuation';

-- Migration: Create inventory_adjustments table
-- Purpose: Track manual stock adjustments (corrections, losses, gains)
-- Different from purchases - these are corrections, not new stock
-- Run in Supabase SQL Editor

CREATE TABLE IF NOT EXISTS inventory_adjustments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    item_id UUID NOT NULL REFERENCES inventory_items(id) ON DELETE CASCADE,
    
    previous_quantity NUMERIC NOT NULL,
    new_quantity NUMERIC NOT NULL,
    adjustment_amount NUMERIC GENERATED ALWAYS AS (new_quantity - previous_quantity) STORED,
    
    reason TEXT NOT NULL,
    adjustment_type TEXT NOT NULL CHECK (adjustment_type IN ('loss', 'gain', 'correction')),
    
    adjusted_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    adjusted_by UUID REFERENCES auth.users(id)
);

-- Add indexes for performance
CREATE INDEX idx_inventory_adjustments_item_id ON inventory_adjustments(item_id);
CREATE INDEX idx_inventory_adjustments_date ON inventory_adjustments(adjusted_at);
CREATE INDEX idx_inventory_adjustments_type ON inventory_adjustments(adjustment_type);

-- Add comments for documentation
COMMENT ON TABLE inventory_adjustments IS 'Tracks manual stock adjustments and corrections';
COMMENT ON COLUMN inventory_adjustments.previous_quantity IS 'Stock quantity before adjustment';
COMMENT ON COLUMN inventory_adjustments.new_quantity IS 'Stock quantity after adjustment';
COMMENT ON COLUMN inventory_adjustments.adjustment_amount IS 'Difference (new - previous), automatically calculated';
COMMENT ON COLUMN inventory_adjustments.reason IS 'Required reason for adjustment (e.g., spillage, counting error, theft)';
COMMENT ON COLUMN inventory_adjustments.adjustment_type IS 'Type: loss (negative), gain (positive), correction (neutral)';
COMMENT ON COLUMN inventory_adjustments.adjusted_at IS 'When the adjustment was made';
COMMENT ON COLUMN inventory_adjustments.adjusted_by IS 'User who made the adjustment';

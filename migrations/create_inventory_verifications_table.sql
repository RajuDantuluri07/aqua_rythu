-- Migration: Create inventory_verifications table
-- Purpose: Track physical stock verification events and mismatches
-- Enables detection of loss, theft, or counting errors
-- Run in Supabase SQL Editor

CREATE TABLE IF NOT EXISTS inventory_verifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    item_id UUID NOT NULL REFERENCES inventory_items(id) ON DELETE CASCADE,
    
    actual_quantity NUMERIC NOT NULL,
    expected_quantity NUMERIC NOT NULL,
    difference NUMERIC NOT NULL,
    status TEXT NOT NULL, -- 'OK', 'LOSS', 'EXTRA'
    
    verified_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    verified_by UUID REFERENCES auth.users(id)
);

-- Add indexes for performance
CREATE INDEX idx_inventory_verifications_item_id ON inventory_verifications(item_id);
CREATE INDEX idx_inventory_verifications_status ON inventory_verifications(status);
CREATE INDEX idx_inventory_verifications_verified_at ON inventory_verifications(verified_at);

-- Add comments for documentation
COMMENT ON TABLE inventory_verifications IS 'Physical stock verification records';
COMMENT ON COLUMN inventory_verifications.actual_quantity IS 'Physically counted quantity';
COMMENT ON COLUMN inventory_verifications.expected_quantity IS 'System-calculated expected quantity';
COMMENT ON COLUMN inventory_verifications.difference IS 'actual - expected (negative = loss)';
COMMENT ON COLUMN inventory_verifications.status IS 'OK (±2 units), LOSS (< -2), EXTRA (> +2)';

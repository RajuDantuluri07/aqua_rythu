-- Migration: Create inventory_purchases table
-- Purpose: Track feed stock purchases for replenishment and cost tracking
-- Run in Supabase SQL Editor

CREATE TABLE IF NOT EXISTS inventory_purchases (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    item_id UUID NOT NULL REFERENCES inventory_items(id) ON DELETE CASCADE,
    
    quantity NUMERIC NOT NULL,
    price_per_unit NUMERIC NOT NULL,
    total_cost NUMERIC GENERATED ALWAYS AS (quantity * price_per_unit) STORED,
    
    purchase_date DATE NOT NULL DEFAULT CURRENT_DATE,
    supplier_name TEXT,
    invoice_number TEXT,
    notes TEXT,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID REFERENCES auth.users(id)
);

-- Add indexes for performance
CREATE INDEX idx_inventory_purchases_item_id ON inventory_purchases(item_id);
CREATE INDEX idx_inventory_purchases_date ON inventory_purchases(purchase_date);
CREATE INDEX idx_inventory_purchases_created_by ON inventory_purchases(created_by);

-- Add comments for documentation
COMMENT ON TABLE inventory_purchases IS 'Records all feed stock purchases for replenishment';
COMMENT ON COLUMN inventory_purchases.quantity IS 'Quantity purchased in inventory units';
COMMENT ON COLUMN inventory_purchases.price_per_unit IS 'Cost per unit (e.g., per kg)';
COMMENT ON COLUMN inventory_purchases.total_cost IS 'Automatically calculated total purchase cost';
COMMENT ON COLUMN inventory_purchases.purchase_date IS 'Date of purchase (default today)';
COMMENT ON COLUMN inventory_purchases.supplier_name IS 'Optional supplier/farm store name';
COMMENT ON COLUMN inventory_purchases.invoice_number IS 'Optional invoice/bill number';

-- Create harvest table for tracking final harvest data
-- Used for calculating final profit (vs estimated profit)

CREATE TABLE harvests (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  
  crop_id uuid NOT NULL,
  total_weight numeric NOT NULL CHECK (total_weight > 0),
  price_per_kg numeric NOT NULL CHECK (price_per_kg > 0),
  
  date date NOT NULL DEFAULT current_date,
  created_at timestamp DEFAULT now(),
  
  -- Foreign key constraints
  CONSTRAINT fk_harvest_crop FOREIGN KEY (crop_id) REFERENCES crops(id) ON DELETE CASCADE
);

-- Create indexes for efficient querying
CREATE INDEX idx_harvests_crop_id ON harvests(crop_id);
CREATE INDEX idx_harvests_date ON harvests(date);

-- Enable Row Level Security
ALTER TABLE harvests ENABLE ROW LEVEL SECURITY;

-- Create RLS policy for user access
CREATE POLICY "user access harvests" ON harvests
FOR ALL
USING (auth.uid() = (SELECT user_id FROM crops WHERE id = crop_id));

-- Add helpful comments
COMMENT ON TABLE harvests IS 'Tracks final harvest data for profit calculation';
COMMENT ON COLUMN harvests.total_weight IS 'Total harvest weight in kg';
COMMENT ON COLUMN harvests.price_per_kg IS 'Selling price per kg';
COMMENT ON COLUMN harvests.date IS 'Date of harvest';

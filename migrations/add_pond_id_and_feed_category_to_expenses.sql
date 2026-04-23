-- Add pond_id column to expenses table (nullable as requested)
ALTER TABLE expenses ADD COLUMN pond_id uuid;

-- Add feed category to the check constraint
ALTER TABLE expenses DROP CONSTRAINT IF EXISTS expenses_category_check;
ALTER TABLE expenses ADD CONSTRAINT expenses_category_check 
  CHECK (category IN ('feed', 'labour', 'electricity', 'diesel', 'sampling', 'other'));

-- Add index for pond_id queries
CREATE INDEX IF NOT EXISTS idx_expenses_pond_date ON expenses (pond_id, date);

-- Add foreign key constraint for pond_id (optional, references ponds table)
-- ALTER TABLE expenses ADD CONSTRAINT fk_expenses_pond 
--   FOREIGN KEY (pond_id) REFERENCES ponds(id) ON DELETE SET NULL;

-- Update comments
COMMENT ON COLUMN expenses.pond_id IS 'Optional pond reference for expense tracking';
COMMENT ON COLUMN expenses.category IS 'Fixed categories: feed, labour, electricity, diesel, sampling, other';

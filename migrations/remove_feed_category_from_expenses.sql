-- Remove feed category from expenses table check constraint
-- Feed cost now only comes from inventory system

ALTER TABLE expenses DROP CONSTRAINT IF EXISTS expenses_category_check;
ALTER TABLE expenses ADD CONSTRAINT expenses_category_check 
  CHECK (category IN ('labour', 'electricity', 'diesel', 'sampling', 'other'));

-- Delete any existing feed expenses since they should come from inventory
DELETE FROM expenses WHERE category = 'feed';

-- Update comments
COMMENT ON COLUMN expenses.category IS 'Fixed categories: labour, electricity, diesel, sampling, other (feed cost comes from inventory)';

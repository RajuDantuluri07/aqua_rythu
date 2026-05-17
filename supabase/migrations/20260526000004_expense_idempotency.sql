-- Add operation_id to expenses for client-side idempotency.
-- A client generates a UUID before the first save attempt and reuses it on
-- retries. The unique index prevents duplicate rows on double-tap or retry.

ALTER TABLE public.expenses
  ADD COLUMN IF NOT EXISTS operation_id UUID DEFAULT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_expenses_operation_id
  ON public.expenses(operation_id)
  WHERE operation_id IS NOT NULL;

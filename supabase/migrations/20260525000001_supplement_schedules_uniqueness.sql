-- Prevent duplicate active schedules for the same pond+product+date+type combination.
-- Uses a partial unique index so completed/paused duplicates are allowed
-- (useful for historical re-scheduling of the same product).

CREATE UNIQUE INDEX IF NOT EXISTS uniq_supplement_schedules_active
  ON public.supplement_schedules(pond_id, start_date, application_type, COALESCE(product_name, ''))
  WHERE status = 'active';

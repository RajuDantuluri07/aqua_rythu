-- TICKET-022: Make inventory_entries.user_id NOT NULL and fix RLS.
--
-- The original column is nullable (20260517000000_inventory_entries.sql:14).
-- RLS uses USING (user_id = auth.uid()), which returns NULL (not TRUE) for rows
-- where user_id IS NULL — making them invisible to all users and impossible to
-- clean up via client queries (orphaned rows).
--
-- Step 1: Backfill any existing NULL rows using the farm owner's user_id
-- so the NOT NULL constraint can be applied without data loss.
UPDATE public.inventory_entries ie
SET user_id = f.user_id
FROM public.farms f
WHERE ie.farm_id = f.id
  AND ie.user_id IS NULL;

-- Step 2: Delete any remaining rows where the farm no longer exists
-- (orphaned by cascade gap) — these cannot be attributed to any user.
DELETE FROM public.inventory_entries
WHERE user_id IS NULL;

-- Step 3: Apply NOT NULL constraint.
ALTER TABLE public.inventory_entries
  ALTER COLUMN user_id SET NOT NULL;

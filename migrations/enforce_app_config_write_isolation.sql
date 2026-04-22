-- Enforce strict write isolation for app_config table
-- This ensures only Edge Functions (service role) can write to app_config
-- All Flutter app access must be read-only

-- Enable RLS if not already enabled
ALTER TABLE app_config ENABLE ROW LEVEL SECURITY;

-- Drop any existing policies that might allow writes
DROP POLICY IF EXISTS "allow_admin_config_write" ON app_config;
DROP POLICY IF EXISTS "allow_config_write" ON app_config;
DROP POLICY IF EXISTS "allow_all_config" ON app_config;

-- Create HARD DENY policy for all direct writes from app
-- This blocks INSERT, UPDATE, DELETE operations from anon/authenticated users
CREATE POLICY "deny_all_direct_writes" ON app_config
FOR INSERT, UPDATE, DELETE
USING (false)
WITH CHECK (false);

-- Create READ-ONLY policy for authenticated users
-- This allows SELECT operations only
CREATE POLICY "allow_config_read" ON app_config
FOR SELECT
USING (auth.role() = 'authenticated');

-- Create READ-ONLY policy for anonymous users (if needed for basic config)
CREATE POLICY "allow_config_read_anon" ON app_config
FOR SELECT
USING (auth.role() = 'anon');

-- Add comment to document the isolation policy
COMMENT ON POLICY "deny_all_direct_writes" ON app_config IS 
'Hard deny policy preventing all direct writes from app. Only service role (Edge Functions) can bypass this.';

COMMENT ON POLICY "allow_config_read" ON app_config IS 
'Read-only access for authenticated users. No write permissions.';

COMMENT ON POLICY "allow_config_read_anon" ON app_config IS 
'Read-only access for anonymous users. No write permissions.';

-- Verify policies are correctly applied
SELECT 
    polname as policy_name,
    polcmd as command_type,
    polpermissive as permissive,
    polroles as roles,
    polwithcheck as with_check,
    polqual as using_condition
FROM pg_policy 
WHERE polrelid = 'app_config'::regclass
ORDER BY polname;

-- Expected results:
-- - deny_all_direct_writes: INSERT, UPDATE, DELETE with USING(false)
-- - allow_config_read: SELECT with USING(auth.role() = 'authenticated')
-- - allow_config_read_anon: SELECT with USING(auth.role() = 'anon')

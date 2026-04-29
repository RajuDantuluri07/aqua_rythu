-- Migration: Add server time function for tamper-proof DOC calculation
-- Purpose: Provides UTC server time to prevent device time manipulation
-- Created: 2026-04-29

-- Create function to get current server time in UTC
create or replace function get_server_time()
returns text
language sql
security definer
as $$
  select now() at time zone 'utc'::text;
$$;

-- Grant execute permission to authenticated users
grant execute on function get_server_time() to authenticated;

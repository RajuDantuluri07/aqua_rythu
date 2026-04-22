-- Insert admin security configuration
INSERT INTO app_config (key, value, created_at, updated_at) 
VALUES (
  'admin_security',
  '{
    "admin_passcode": "0000",
    "admin_user_id": "3fd14940-833f-413c-9da6-7b157d41050d"
  }',
  NOW(),
  NOW() 
) ON CONFLICT (key) DO UPDATE SET
  value = EXCLUDED.value,
  updated_at = NOW();

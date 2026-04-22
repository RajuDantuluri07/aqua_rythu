-- Create config_logs table for audit logging
CREATE TABLE IF NOT EXISTS config_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    changed_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    change JSONB NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Add indexes for performance
    INDEX idx_config_logs_changed_by (changed_by),
    INDEX idx_config_logs_created_at (created_at),
    INDEX idx_config_logs_change_type USING GIN ((change->>'type'))
);

-- Enable RLS
ALTER TABLE config_logs ENABLE ROW LEVEL SECURITY;

-- Create RLS policy for admin users to view all logs
CREATE POLICY "Admin users can view all config logs" ON config_logs
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE profiles.id = auth.uid() 
            AND profiles.role = 'admin'
        )
    );

-- Create RLS policy for Edge Function to insert logs (service role bypasses RLS)
-- Note: The Edge Function will use service role, so this policy is for transparency
CREATE POLICY "Service role can insert config logs" ON config_logs
    FOR INSERT WITH CHECK (
        auth.role() = 'service_role'
    );

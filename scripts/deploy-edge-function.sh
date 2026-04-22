#!/bin/bash

# Deploy Edge Function for secure admin config updates
echo "Deploying update-app-config Edge Function..."

# Check if supabase CLI is installed
if ! command -v supabase &> /dev/null; then
    echo "Error: Supabase CLI is not installed. Please install it first:"
    echo "npm install -g supabase"
    exit 1
fi

# Deploy the Edge Function
supabase functions deploy update-app-config --no-verify-jwt

echo "Edge Function deployed successfully!"
echo ""
echo "Next steps:"
echo "1. Run the admin audit log migration:"
echo "   psql -d your_database -f migrations/create_admin_audit_log.sql"
echo ""
echo "2. Test the secure admin access:"
echo "   - 5 taps on farm icon in dashboard"
echo "   - Enter passcode: 0000"
echo "   - Verify admin panel loads and can update configs"

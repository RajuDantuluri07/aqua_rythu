#!/bin/bash

# Deploy all Edge Functions for AquaRythu admin system
echo "Deploying AquaRythu Edge Functions..."

# Check if supabase CLI is installed
if ! command -v supabase &> /dev/null; then
    echo "Error: Supabase CLI is not installed. Please install it first:"
    echo "npm install -g supabase"
    exit 1
fi

# Deploy update-app-config function
echo "Deploying update-app-config function..."
supabase functions deploy update-app-config --no-verify-jwt

if [ $? -eq 0 ]; then
    echo "update-app-config deployed successfully!"
else
    echo "Failed to deploy update-app-config"
    exit 1
fi

# Deploy validate-admin-passcode function
echo "Deploying validate-admin-passcode function..."
supabase functions deploy validate-admin-passcode --no-verify-jwt

if [ $? -eq 0 ]; then
    echo "validate-admin-passcode deployed successfully!"
else
    echo "Failed to deploy validate-admin-passcode"
    exit 1
fi

# Deploy rollback-config function
echo "Deploying rollback-config function..."
supabase functions deploy rollback-config --no-verify-jwt

if [ $? -eq 0 ]; then
    echo "rollback-config deployed successfully!"
else
    echo "Failed to deploy rollback-config"
    exit 1
fi

echo "All Edge Functions deployed successfully!"
echo ""
echo "Next steps:"
echo "1. Run database migrations: ./scripts/run-migrations.sh"
echo "2. Test the admin system: 5 taps on farm icon -> passcode: 0000"
echo "3. Verify Edge Functions are working: check Supabase dashboard"

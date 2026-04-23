#!/bin/bash

# Run all database migrations for AquaRythu admin system
echo "Running AquaRythu database migrations..."

# Check if psql is installed
if ! command -v psql &> /dev/null; then
    echo "Error: psql is not installed. Please install PostgreSQL client."
    echo "On macOS: brew install postgresql"
    echo "On Ubuntu: sudo apt-get install postgresql-client"
    exit 1
fi

# Database connection parameters
DB_HOST=${DB_HOST:-localhost}
DB_PORT=${DB_PORT:-5432}
DB_NAME=${DB_NAME:-aqua_rythu}
DB_USER=${DB_USER:-postgres}

echo "Connecting to database: $DB_NAME on $DB_HOST:$DB_PORT"

# Function to run migration
run_migration() {
    local migration_file=$1
    local description=$2
    
    echo "Running migration: $description"
    echo "File: $migration_file"
    
    if psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f "$migration_file"; then
        echo "Migration completed successfully: $description"
    else
        echo "Failed to run migration: $description"
        return 1
    fi
    echo ""
}

# Run migrations in order
run_migration "migrations/create_app_config_table.sql" "Create app_config table"
run_migration "migrations/add_admin_security_config.sql" "Add admin security config"
run_migration "migrations/add_config_versioning.sql" "Add config versioning system"
run_migration "migrations/create_admin_audit_log.sql" "Create admin audit log table"
run_migration "migrations/create_config_logs.sql" "Create config logs table"
run_migration "migrations/enforce_app_config_write_isolation.sql" "Enforce app_config write isolation"

echo "All database migrations completed successfully!"
echo ""
echo "Migration summary:"
echo "- app_config table with versioning"
echo "- admin security configuration"
echo "- audit logging tables"
echo "- triggers and constraints"
echo ""
echo "Next steps:"
echo "1. Deploy Edge Functions: ./scripts/deploy-all-edge-functions.sh"
echo "2. Test admin system: 5 taps on farm icon -> passcode: 0000"
echo "3. Verify all tables and data in Supabase dashboard"

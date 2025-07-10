#!/bin/bash

set -e

ENVIRONMENT=""
MIGRATION_DIR=""
DRY_RUN=false

usage() {
    echo "Usage: $0 -e ENVIRONMENT [-m MIGRATION_DIR] [-d]"
    echo "  -e ENVIRONMENT     Target environment (dev, stage, prod)"
    echo "  -m MIGRATION_DIR   Directory containing migration files (default: ../migrations)"
    echo "  -d                 Dry run - show what would be executed without running"
    echo ""
    echo "Examples:"
    echo "  $0 -e dev"
    echo "  $0 -e prod -m ./custom-migrations"
    echo "  $0 -e stage -d"
    exit 1
}

while getopts "e:m:d" opt; do
    case $opt in
        e)
            ENVIRONMENT="$OPTARG"
            ;;
        m)
            MIGRATION_DIR="$OPTARG"
            ;;
        d)
            DRY_RUN=true
            ;;
        *)
            usage
            ;;
    esac
done

if [ -z "$ENVIRONMENT" ]; then
    echo "Error: Environment is required"
    usage
fi

if [[ ! "$ENVIRONMENT" =~ ^(dev|stage|prod)$ ]]; then
    echo "Error: Environment must be one of: dev, stage, prod"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

if [ -z "$MIGRATION_DIR" ]; then
    MIGRATION_DIR="$PROJECT_DIR/migrations"
fi

if [ ! -d "$MIGRATION_DIR" ]; then
    echo "Error: Migration directory not found: $MIGRATION_DIR"
    exit 1
fi

echo "=== Database Migration for $ENVIRONMENT ==="
echo "Environment: $ENVIRONMENT"
echo "Migration Directory: $MIGRATION_DIR"
echo "Dry Run: $DRY_RUN"
echo ""

ENV_DIR="$PROJECT_DIR/environments/$ENVIRONMENT"
cd "$ENV_DIR"

echo "Getting database connection details..."
DB_SECRET_NAME=$(terraform output -raw db_secret_name)

if [ -z "$DB_SECRET_NAME" ]; then
    echo "Error: Could not retrieve database secret name from Terraform output"
    exit 1
fi

echo "Retrieving database credentials from AWS Secrets Manager..."
DB_CREDENTIALS=$(aws secretsmanager get-secret-value --secret-id "$DB_SECRET_NAME" --query SecretString --output text)

DB_HOST=$(echo "$DB_CREDENTIALS" | jq -r '.host' | sed 's/:5432$//')
DB_PORT=$(echo "$DB_CREDENTIALS" | jq -r '.port')
DB_NAME=$(echo "$DB_CREDENTIALS" | jq -r '.dbname')
DB_USER=$(echo "$DB_CREDENTIALS" | jq -r '.username')
DB_PASSWORD=$(echo "$DB_CREDENTIALS" | jq -r '.password')

echo "Database: $DB_HOST:$DB_PORT/$DB_NAME"
echo "User: $DB_USER"
echo ""

export PGPASSWORD="$DB_PASSWORD"

echo "Testing database connection..."
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT version();" > /dev/null

echo "Database connection successful!"
echo ""

MIGRATION_FILES=$(find "$MIGRATION_DIR" -name "*.sql" | sort)

if [ -z "$MIGRATION_FILES" ]; then
    echo "No migration files found in $MIGRATION_DIR"
    exit 0
fi

echo "Found migration files:"
echo "$MIGRATION_FILES"
echo ""

if [ "$DRY_RUN" = true ]; then
    echo "DRY RUN - The following migrations would be executed:"
    for file in $MIGRATION_FILES; do
        echo "--- $(basename "$file") ---"
        cat "$file"
        echo ""
    done
    exit 0
fi

if [ "$ENVIRONMENT" = "prod" ]; then
    echo "WARNING: You are about to run migrations on PRODUCTION!"
    read -p "Type 'migrate-prod' to confirm: " confirm
    if [ "$confirm" != "migrate-prod" ]; then
        echo "Migration cancelled"
        exit 1
    fi
fi

echo "Creating migrations tracking table if it doesn't exist..."
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "
CREATE TABLE IF NOT EXISTS schema_migrations (
    version VARCHAR(255) PRIMARY KEY,
    applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);"

echo "Running migrations..."
for file in $MIGRATION_FILES; do
    filename=$(basename "$file")
    version="${filename%.*}"
    
    ALREADY_APPLIED=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT version FROM schema_migrations WHERE version = '$version';" | xargs)
    
    if [ -n "$ALREADY_APPLIED" ]; then
        echo "⏭️  Skipping $filename (already applied)"
        continue
    fi
    
    echo "🚀 Applying $filename..."
    
    if psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f "$file"; then
        psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "INSERT INTO schema_migrations (version) VALUES ('$version');"
        echo "✅ Successfully applied $filename"
    else
        echo "❌ Failed to apply $filename"
        exit 1
    fi
    
    echo ""
done

echo "=== Migration completed successfully ==="
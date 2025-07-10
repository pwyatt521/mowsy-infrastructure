#!/bin/bash

set -e

ENVIRONMENT=""
BACKUP_TYPE="full"

usage() {
    echo "Usage: $0 -e ENVIRONMENT [-t BACKUP_TYPE]"
    echo "  -e ENVIRONMENT   Target environment (dev, stage, prod)"
    echo "  -t BACKUP_TYPE   Type of backup (full, schema-only, data-only) [default: full]"
    echo ""
    echo "Examples:"
    echo "  $0 -e dev"
    echo "  $0 -e prod -t schema-only"
    exit 1
}

while getopts "e:t:" opt; do
    case $opt in
        e)
            ENVIRONMENT="$OPTARG"
            ;;
        t)
            BACKUP_TYPE="$OPTARG"
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

if [[ ! "$BACKUP_TYPE" =~ ^(full|schema-only|data-only)$ ]]; then
    echo "Error: Backup type must be one of: full, schema-only, data-only"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ENV_DIR="$PROJECT_DIR/environments/$ENVIRONMENT"

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILENAME="mowsy_${ENVIRONMENT}_${BACKUP_TYPE}_${TIMESTAMP}.sql"

echo "=== Database Backup for $ENVIRONMENT ==="
echo "Environment: $ENVIRONMENT"
echo "Backup Type: $BACKUP_TYPE"
echo "Backup File: $BACKUP_FILENAME"
echo ""

cd "$ENV_DIR"

echo "Getting database connection details..."
DB_SECRET_NAME=$(terraform output -raw db_secret_name)
S3_BACKUP_BUCKET=$(terraform output -raw s3_backups_bucket)

if [ -z "$DB_SECRET_NAME" ] || [ -z "$S3_BACKUP_BUCKET" ]; then
    echo "Error: Could not retrieve required outputs from Terraform"
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
echo "S3 Bucket: $S3_BACKUP_BUCKET"
echo ""

export PGPASSWORD="$DB_PASSWORD"

echo "Testing database connection..."
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT version();" > /dev/null
echo "Database connection successful!"
echo ""

echo "Creating database backup..."

case $BACKUP_TYPE in
    "full")
        pg_dump -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
            --verbose --clean --create > "$BACKUP_FILENAME"
        ;;
    "schema-only")
        pg_dump -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
            --verbose --schema-only > "$BACKUP_FILENAME"
        ;;
    "data-only")
        pg_dump -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
            --verbose --data-only > "$BACKUP_FILENAME"
        ;;
esac

echo "Compressing backup..."
gzip "$BACKUP_FILENAME"
COMPRESSED_BACKUP="${BACKUP_FILENAME}.gz"

echo "Uploading backup to S3..."
aws s3 cp "$COMPRESSED_BACKUP" "s3://$S3_BACKUP_BUCKET/database-backups/$COMPRESSED_BACKUP"

echo "Backup size: $(du -h "$COMPRESSED_BACKUP" | cut -f1)"

if [ "$ENVIRONMENT" != "prod" ]; then
    echo "Cleaning up local backup file..."
    rm "$COMPRESSED_BACKUP"
else
    echo "Keeping local backup file for production environment"
fi

echo ""
echo "=== Backup completed successfully ==="
echo "Backup location: s3://$S3_BACKUP_BUCKET/database-backups/$COMPRESSED_BACKUP"
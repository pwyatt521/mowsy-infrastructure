#!/bin/bash

set -e

ENVIRONMENT=""
BACKUP_FILE=""
DRY_RUN=false

usage() {
    echo "Usage: $0 -e ENVIRONMENT -f BACKUP_FILE [-d]"
    echo "  -e ENVIRONMENT   Target environment (dev, stage, prod)"
    echo "  -f BACKUP_FILE   Backup file name (from S3 bucket) or local file path"
    echo "  -d               Dry run - download and inspect backup without restoring"
    echo ""
    echo "Examples:"
    echo "  $0 -e dev -f mowsy_prod_full_20231201_120000.sql.gz"
    echo "  $0 -e stage -f ./local-backup.sql.gz -d"
    exit 1
}

while getopts "e:f:d" opt; do
    case $opt in
        e)
            ENVIRONMENT="$OPTARG"
            ;;
        f)
            BACKUP_FILE="$OPTARG"
            ;;
        d)
            DRY_RUN=true
            ;;
        *)
            usage
            ;;
    esac
done

if [ -z "$ENVIRONMENT" ] || [ -z "$BACKUP_FILE" ]; then
    echo "Error: Environment and backup file are required"
    usage
fi

if [[ ! "$ENVIRONMENT" =~ ^(dev|stage|prod)$ ]]; then
    echo "Error: Environment must be one of: dev, stage, prod"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ENV_DIR="$PROJECT_DIR/environments/$ENVIRONMENT"

echo "=== Database Restore for $ENVIRONMENT ==="
echo "Environment: $ENVIRONMENT"
echo "Backup File: $BACKUP_FILE"
echo "Dry Run: $DRY_RUN"
echo ""

if [ "$ENVIRONMENT" = "prod" ] && [ "$DRY_RUN" = false ]; then
    echo "WARNING: You are about to restore the PRODUCTION database!"
    echo "This will OVERWRITE all existing data in the production database."
    read -p "Type 'restore-prod' to confirm: " confirm
    if [ "$confirm" != "restore-prod" ]; then
        echo "Restore cancelled"
        exit 1
    fi
fi

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
echo ""

export PGPASSWORD="$DB_PASSWORD"

echo "Testing database connection..."
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT version();" > /dev/null
echo "Database connection successful!"
echo ""

LOCAL_BACKUP_FILE="$(basename "$BACKUP_FILE")"

if [ -f "$BACKUP_FILE" ]; then
    echo "Using local backup file: $BACKUP_FILE"
    cp "$BACKUP_FILE" "$LOCAL_BACKUP_FILE"
else
    echo "Downloading backup from S3..."
    aws s3 cp "s3://$S3_BACKUP_BUCKET/database-backups/$BACKUP_FILE" "$LOCAL_BACKUP_FILE"
fi

if [ ! -f "$LOCAL_BACKUP_FILE" ]; then
    echo "Error: Backup file not found: $LOCAL_BACKUP_FILE"
    exit 1
fi

echo "Backup file size: $(du -h "$LOCAL_BACKUP_FILE" | cut -f1)"

if [[ "$LOCAL_BACKUP_FILE" == *.gz ]]; then
    echo "Decompressing backup..."
    gunzip -c "$LOCAL_BACKUP_FILE" > "${LOCAL_BACKUP_FILE%.gz}"
    DECOMPRESSED_FILE="${LOCAL_BACKUP_FILE%.gz}"
else
    DECOMPRESSED_FILE="$LOCAL_BACKUP_FILE"
fi

echo "Inspecting backup file..."
echo "First few lines of backup:"
head -n 20 "$DECOMPRESSED_FILE" | grep -E "^(--|CREATE|INSERT|COPY)" | head -n 10

if [ "$DRY_RUN" = true ]; then
    echo ""
    echo "DRY RUN - Backup inspection completed"
    echo "Backup file is ready for restore: $DECOMPRESSED_FILE"
    echo "To restore, run the same command without -d flag"
    rm -f "$LOCAL_BACKUP_FILE" "$DECOMPRESSED_FILE" 2>/dev/null || true
    exit 0
fi

echo ""
echo "Creating pre-restore backup..."
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
PRE_RESTORE_BACKUP="pre_restore_${ENVIRONMENT}_${TIMESTAMP}.sql"

pg_dump -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
    --verbose --clean --create > "$PRE_RESTORE_BACKUP"

gzip "$PRE_RESTORE_BACKUP"
aws s3 cp "${PRE_RESTORE_BACKUP}.gz" "s3://$S3_BACKUP_BUCKET/database-backups/${PRE_RESTORE_BACKUP}.gz"

echo "Pre-restore backup saved to: s3://$S3_BACKUP_BUCKET/database-backups/${PRE_RESTORE_BACKUP}.gz"
echo ""

echo "Restoring database..."
echo "This may take several minutes depending on the backup size..."

if psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres -f "$DECOMPRESSED_FILE"; then
    echo "✅ Database restore completed successfully"
else
    echo "❌ Database restore failed"
    echo ""
    echo "Pre-restore backup is available at:"
    echo "s3://$S3_BACKUP_BUCKET/database-backups/${PRE_RESTORE_BACKUP}.gz"
    exit 1
fi

echo "Cleaning up temporary files..."
rm -f "$LOCAL_BACKUP_FILE" "$DECOMPRESSED_FILE" "${PRE_RESTORE_BACKUP}.gz" 2>/dev/null || true

echo ""
echo "=== Restore completed successfully ==="
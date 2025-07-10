#!/bin/bash

set -e

ENVIRONMENT=""

usage() {
    echo "Usage: $0 -e ENVIRONMENT"
    echo "  -e ENVIRONMENT  Target environment (dev, stage, prod)"
    echo ""
    echo "This script creates the S3 bucket and DynamoDB table for Terraform state backend."
    echo ""
    echo "Examples:"
    echo "  $0 -e dev"
    echo "  $0 -e prod"
    exit 1
}

while getopts "e:" opt; do
    case $opt in
        e)
            ENVIRONMENT="$OPTARG"
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

AWS_REGION="us-east-2"
BUCKET_NAME="mowsy-terraform-state-$ENVIRONMENT"
DYNAMODB_TABLE="mowsy-terraform-locks"

echo "=== Setting up Terraform Backend for $ENVIRONMENT ==="
echo "S3 Bucket: $BUCKET_NAME"
echo "DynamoDB Table: $DYNAMODB_TABLE"
echo "Region: $AWS_REGION"
echo ""

echo "Creating S3 bucket for Terraform state..."
aws s3api create-bucket \
    --bucket "$BUCKET_NAME" \
    --region "$AWS_REGION" \
    --create-bucket-configuration LocationConstraint="$AWS_REGION" 2>/dev/null || {
    echo "Bucket already exists or error occurred, continuing..."
}

echo "Enabling versioning on S3 bucket..."
aws s3api put-bucket-versioning \
    --bucket "$BUCKET_NAME" \
    --versioning-configuration Status=Enabled

echo "Enabling server-side encryption on S3 bucket..."
aws s3api put-bucket-encryption \
    --bucket "$BUCKET_NAME" \
    --server-side-encryption-configuration '{
        "Rules": [
            {
                "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "AES256"
                }
            }
        ]
    }'

echo "Blocking public access on S3 bucket..."
aws s3api put-public-access-block \
    --bucket "$BUCKET_NAME" \
    --public-access-block-configuration \
        BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

if [ "$ENVIRONMENT" = "dev" ]; then
    echo "Creating DynamoDB table for state locking..."
    aws dynamodb create-table \
        --table-name "$DYNAMODB_TABLE" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
        --region "$AWS_REGION" 2>/dev/null || {
        echo "DynamoDB table already exists or error occurred, continuing..."
    }
fi

echo ""
echo "=== Backend setup completed successfully ==="
echo ""
echo "You can now run terraform init in the environments/$ENVIRONMENT directory."
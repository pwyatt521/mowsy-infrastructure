#!/bin/bash

set -e

ENVIRONMENT=""
AUTO_APPROVE=false
DESTROY=false

usage() {
    echo "Usage: $0 -e ENVIRONMENT [-a] [-d]"
    echo "  -e ENVIRONMENT  Target environment (dev, stage, prod)"
    echo "  -a              Auto-approve (skip interactive approval)"
    echo "  -d              Destroy instead of apply"
    echo ""
    echo "Examples:"
    echo "  $0 -e dev"
    echo "  $0 -e prod -a"
    echo "  $0 -e stage -d"
    exit 1
}

while getopts "e:ad" opt; do
    case $opt in
        e)
            ENVIRONMENT="$OPTARG"
            ;;
        a)
            AUTO_APPROVE=true
            ;;
        d)
            DESTROY=true
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
ENV_DIR="$PROJECT_DIR/environments/$ENVIRONMENT"

if [ ! -d "$ENV_DIR" ]; then
    echo "Error: Environment directory not found: $ENV_DIR"
    exit 1
fi

if [ ! -f "$ENV_DIR/terraform.tfvars" ]; then
    echo "Error: terraform.tfvars not found in $ENV_DIR"
    echo "Please copy terraform.tfvars.example to terraform.tfvars and configure it"
    exit 1
fi

echo "=== Mowsy Infrastructure Deployment ==="
echo "Environment: $ENVIRONMENT"
echo "Directory: $ENV_DIR"
echo "Action: $([ "$DESTROY" = true ] && echo "DESTROY" || echo "DEPLOY")"
echo ""

if [ "$DESTROY" = true ] && [ "$ENVIRONMENT" = "prod" ]; then
    echo "WARNING: You are about to DESTROY the PRODUCTION environment!"
    echo "This action is irreversible and will delete all resources."
    read -p "Type 'destroy-prod' to confirm: " confirm
    if [ "$confirm" != "destroy-prod" ]; then
        echo "Deployment cancelled"
        exit 1
    fi
fi

cd "$ENV_DIR"

echo "Initializing Terraform..."
terraform init

echo "Validating configuration..."
terraform validate

echo "Planning changes..."
if [ "$DESTROY" = true ]; then
    terraform plan -destroy -var-file=terraform.tfvars
else
    terraform plan -var-file=terraform.tfvars
fi

if [ "$AUTO_APPROVE" = false ]; then
    echo ""
    read -p "Do you want to proceed? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Deployment cancelled"
        exit 1
    fi
fi

echo "Applying changes..."
if [ "$DESTROY" = true ]; then
    terraform destroy -var-file=terraform.tfvars -auto-approve
    echo "=== Environment $ENVIRONMENT destroyed successfully ==="
else
    terraform apply -var-file=terraform.tfvars -auto-approve
    echo "=== Environment $ENVIRONMENT deployed successfully ==="
    
    echo ""
    echo "=== Deployment Summary ==="
    terraform output
fi
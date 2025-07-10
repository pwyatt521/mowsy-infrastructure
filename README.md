# Mowsy Infrastructure

AWS serverless infrastructure for the Mowsy hyperlocal gig economy platform, built with Terraform and optimized for the AWS free tier.

## 🏗️ Architecture Overview

This infrastructure deploys a complete serverless application stack across three environments (dev, stage, prod) with the following components:

- **API Gateway** - RESTful API endpoints with CORS support
- **Lambda Functions** - Go-based microservices for auth, jobs, equipment, payments, and admin
- **RDS PostgreSQL** - Managed database with automated backups
- **S3 Buckets** - File storage for uploads and backups
- **VPC** - Isolated networking with public/private subnets
- **Secrets Manager** - Secure storage for API keys and credentials
- **CloudWatch** - Monitoring, logging, and alerting

## 📁 Project Structure

```
mowsy-infrastructure/
├── environments/          # Environment-specific configurations
│   ├── dev/              # Development environment
│   ├── stage/            # Staging environment
│   └── prod/             # Production environment
├── modules/              # Reusable Terraform modules
│   ├── vpc/              # VPC, subnets, security groups
│   ├── lambda/           # Lambda functions and IAM roles
│   ├── rds/              # PostgreSQL database
│   ├── s3/               # S3 buckets and policies
│   ├── api-gateway/      # API Gateway configuration
│   ├── secrets/          # Secrets Manager resources
│   └── monitoring/       # CloudWatch dashboards and alarms
├── scripts/              # Management and deployment scripts
├── migrations/           # Database migration files
└── README.md
```

## 🚀 Quick Start

### Prerequisites

1. **AWS CLI** configured with appropriate credentials
2. **Terraform** >= 1.0 installed
3. **PostgreSQL client** (psql) for database operations
4. **jq** for JSON processing in scripts

### 1. Setup Terraform Backend

First, create the S3 bucket and DynamoDB table for Terraform state:

```bash
# Setup backend for dev environment
./scripts/setup-backend.sh -e dev

# Setup backend for other environments
./scripts/setup-backend.sh -e stage
./scripts/setup-backend.sh -e prod
```

### 2. Configure Environment Variables

Copy the example tfvars file and configure your environment:

```bash
cp environments/dev/terraform.tfvars.example environments/dev/terraform.tfvars
```

Edit `terraform.tfvars` with your actual values:

```hcl
# Required secrets (generate secure values)
jwt_secret             = "your-jwt-secret-here"
stripe_secret_key      = "sk_test_your-stripe-secret-key"
stripe_publishable_key = "pk_test_your-stripe-publishable-key"
stripe_webhook_secret  = "whsec_your-webhook-secret"
geocodio_api_key       = "your-geocodio-api-key"
sendgrid_api_key       = "your-sendgrid-api-key"

# Alert emails
alert_email_addresses = ["admin@mowsy.com"]
```

### 3. Deploy Infrastructure

Deploy to your target environment:

```bash
# Deploy dev environment
./scripts/deploy.sh -e dev

# Deploy with auto-approval (for CI/CD)
./scripts/deploy.sh -e prod -a
```

### 4. Run Database Migrations

After deployment, initialize the database schema:

```bash
# Run migrations
./scripts/migrate-db.sh -e dev

# Dry run to preview migrations
./scripts/migrate-db.sh -e dev -d
```

## 🌍 Environment Configurations

### Development (dev)
- **Purpose**: Local development and testing
- **Resources**: Minimal for cost optimization
- **Database**: db.t3.micro, single AZ
- **Lambda**: 256MB memory, no provisioned concurrency
- **Networking**: No NAT Gateway (cost savings)
- **Monitoring**: 7-day log retention

### Staging (stage)
- **Purpose**: Pre-production testing
- **Resources**: Production-like configuration
- **Database**: db.t3.micro, single AZ with backups
- **Lambda**: 512MB memory, no provisioned concurrency
- **Networking**: NAT Gateway enabled
- **Monitoring**: 14-day log retention

### Production (prod)
- **Purpose**: Live application environment
- **Resources**: High availability and performance
- **Database**: db.t3.small, Multi-AZ with 30-day backups
- **Lambda**: 512MB memory with provisioned concurrency
- **Networking**: NAT Gateway with 3 AZs
- **Monitoring**: 30-day log retention, enhanced monitoring

## 🛠️ Management Scripts

### Deployment
```bash
# Deploy infrastructure
./scripts/deploy.sh -e ENVIRONMENT [-a] [-d]

# Options:
#   -e  Environment (dev, stage, prod)
#   -a  Auto-approve (skip confirmation)
#   -d  Destroy instead of deploy
```

### Database Management
```bash
# Run migrations
./scripts/migrate-db.sh -e ENVIRONMENT [-m MIGRATION_DIR] [-d]

# Backup database
./scripts/backup-db.sh -e ENVIRONMENT [-t BACKUP_TYPE]

# Restore database
./scripts/restore-db.sh -e ENVIRONMENT -f BACKUP_FILE [-d]
```

### Backend Setup
```bash
# Setup Terraform state backend
./scripts/setup-backend.sh -e ENVIRONMENT
```

## 💾 Database Management

### Migrations

Database migrations are stored in the `migrations/` directory and executed in order:

```
migrations/
├── 001_initial_schema.sql      # Core tables and indexes
├── 002_add_notifications.sql   # Notification system
└── ...                         # Additional migrations
```

Create new migrations following the naming convention: `XXX_description.sql`

### Backup Strategy

- **Automated**: RDS automated backups (7-30 days retention)
- **Manual**: Script-based backups stored in S3
- **Pre-restore**: Automatic backup before restore operations

## 🔐 Security Features

### Network Security
- Private subnets for databases
- Security groups with minimal required access
- VPC endpoints for S3 to avoid internet traffic
- NAT Gateways for secure outbound access

### Data Protection
- Encryption at rest for RDS and S3
- Secrets Manager for sensitive data
- SSL/TLS enforced for all connections
- IAM roles with least privilege access

### Access Control
- Separate environments with isolated resources
- Environment-specific IAM policies
- API Gateway throttling and usage plans
- CloudWatch monitoring and alerting

## 📊 Monitoring & Alerting

### CloudWatch Dashboards
Each environment includes dashboards for:
- Lambda function metrics (duration, errors, invocations)
- RDS performance (CPU, connections, storage)
- API Gateway metrics (requests, latency, errors)

### Alerts
Automatic alerts for:
- Lambda function errors and duration
- RDS CPU utilization and connections
- API Gateway 5XX errors
- High resource usage

### Logging
- Centralized logging in CloudWatch
- Structured log formats
- Environment-specific retention policies
- Log aggregation across services

## 💰 Cost Optimization

### AWS Free Tier Usage
- **RDS**: db.t3.micro instances (750 hours/month)
- **Lambda**: 1M requests and 400,000 GB-seconds/month
- **API Gateway**: 1M API calls/month
- **S3**: 5GB storage, 20K GET requests, 2K PUT requests
- **CloudWatch**: 10 custom metrics and alarms

### Cost-Saving Features
- Lifecycle policies for S3 objects
- Automatic log retention policies
- Resource scheduling for non-prod environments
- Optimized instance classes per environment

## 🔧 Troubleshooting

### Common Issues

**Terraform Backend Not Found**
```bash
# Solution: Setup backend first
./scripts/setup-backend.sh -e dev
```

**Lambda Deployment Fails**
```bash
# Solution: Ensure Lambda ZIP files exist
# Build your Go functions and create ZIP files in the lambdas/ directory
```

**Database Connection Fails**
```bash
# Solution: Check security groups and ensure Lambda is in VPC
terraform output rds_endpoint  # Verify endpoint is accessible
```

**Migration Fails**
```bash
# Solution: Check database connectivity and permissions
./scripts/migrate-db.sh -e dev -d  # Dry run to diagnose
```

### Debug Commands
```bash
# Check Terraform state
terraform show

# View specific resource
terraform state show module.rds.aws_db_instance.main

# Get outputs
terraform output

# Check AWS resources
aws rds describe-db-instances
aws lambda list-functions
```

## 🚢 Deployment Pipeline

### CI/CD Integration

Example GitHub Actions workflow:

```yaml
name: Deploy Infrastructure
on:
  push:
    branches: [main]
    paths: ['environments/prod/**']

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: hashicorp/setup-terraform@v2
      - name: Deploy Production
        run: ./scripts/deploy.sh -e prod -a
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
```

### Environment Promotion

```bash
# Test in dev
./scripts/deploy.sh -e dev

# Promote to stage
./scripts/deploy.sh -e stage

# Deploy to production
./scripts/deploy.sh -e prod
```

## 📋 API Endpoints

After deployment, your API will be available at:

```
https://{api-id}.execute-api.us-east-2.amazonaws.com/{environment}/v1/
```

### Endpoint Structure
- `POST /v1/auth/login` - User authentication
- `GET /v1/jobs` - List jobs
- `POST /v1/jobs` - Create job
- `GET /v1/equipment` - List equipment
- `POST /v1/payments/process` - Process payment
- `GET /v1/admin/users` - Admin endpoints

## 🆘 Support

For issues and questions:

1. Check the troubleshooting section above
2. Review CloudWatch logs for error details
3. Verify environment configuration
4. Check AWS service limits and quotas

## 📜 License

This infrastructure code is proprietary to Mowsy. All rights reserved.

---

Built with ❤️ for the Mowsy platform

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }

  backend "s3" {
    bucket = "mowsy-terraform-state-dev"
    key    = "dev/terraform.tfstate"
    region = "us-east-2"
    
    dynamodb_table = "mowsy-terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = "dev"
      Project     = "mowsy"
      ManagedBy   = "terraform"
    }
  }
}

locals {
  environment = "dev"
  
  lambda_functions = {
    auth = {
      filename               = "../../lambdas/auth.zip"
      handler               = "main"
      environment_variables = {
        DB_SECRET_NAME = module.secrets.app_secrets_name
        S3_BUCKET      = module.s3.uploads_bucket_name
      }
      provisioned_concurrency = 0
    }
    jobs = {
      filename               = "../../lambdas/jobs.zip"
      handler               = "main"
      environment_variables = {
        DB_SECRET_NAME = module.secrets.app_secrets_name
        S3_BUCKET      = module.s3.uploads_bucket_name
      }
      provisioned_concurrency = 0
    }
    equipment = {
      filename               = "../../lambdas/equipment.zip"
      handler               = "main"
      environment_variables = {
        DB_SECRET_NAME = module.secrets.app_secrets_name
        S3_BUCKET      = module.s3.uploads_bucket_name
      }
      provisioned_concurrency = 0
    }
    payments = {
      filename               = "../../lambdas/payments.zip"
      handler               = "main"
      environment_variables = {
        DB_SECRET_NAME    = module.secrets.app_secrets_name
        STRIPE_SECRET_ARN = module.secrets.stripe_secrets_arn
      }
      provisioned_concurrency = 0
    }
    admin = {
      filename               = "../../lambdas/admin.zip"
      handler               = "main"
      environment_variables = {
        DB_SECRET_NAME = module.secrets.app_secrets_name
        S3_BUCKET      = module.s3.uploads_bucket_name
      }
      provisioned_concurrency = 0
    }
  }
}

module "vpc" {
  source = "../../modules/vpc"

  environment         = local.environment
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  aws_region         = var.aws_region
  enable_nat_gateway = false
}

module "s3" {
  source = "../../modules/s3"

  environment             = local.environment
  enable_versioning      = false
  cors_allowed_origins   = ["http://localhost:3000", "https://dev.mowsy.com"]
  object_expiration_days = 90
  backup_retention_days  = 365
}

module "secrets" {
  source = "../../modules/secrets"

  environment            = local.environment
  jwt_secret            = var.jwt_secret
  stripe_secret_key     = var.stripe_secret_key
  stripe_publishable_key = var.stripe_publishable_key
  stripe_webhook_secret  = var.stripe_webhook_secret
  geocodio_api_key      = var.geocodio_api_key
  sendgrid_api_key      = var.sendgrid_api_key
}

module "rds" {
  source = "../../modules/rds"

  environment              = local.environment
  private_subnet_ids       = module.vpc.private_subnet_ids
  rds_security_group_id    = module.vpc.rds_security_group_id
  db_instance_class        = var.db_instance_class
  db_allocated_storage     = 20
  db_max_allocated_storage = 50
  backup_retention_period  = 7
  multi_az                = false
}

module "lambda" {
  source = "../../modules/lambda"

  environment                = local.environment
  lambda_functions          = local.lambda_functions
  lambda_memory_size        = var.lambda_memory_size
  lambda_timeout            = 30
  log_retention_days        = 7
  private_subnet_ids        = module.vpc.private_subnet_ids
  lambda_security_group_id  = module.vpc.lambda_security_group_id
  secrets_manager_arn       = module.secrets.app_secrets_arn
  s3_bucket_arn            = module.s3.uploads_bucket_arn
  api_gateway_execution_arn = module.api_gateway.api_gateway_execution_arn
}

module "api_gateway" {
  source = "../../modules/api-gateway"

  environment         = local.environment
  lambda_invoke_arns  = module.lambda.lambda_function_invoke_arns
  log_retention_days  = 7
  quota_limit         = 5000
  throttle_rate_limit = 50
  throttle_burst_limit = 100
}

module "monitoring" {
  source = "../../modules/monitoring"

  environment            = local.environment
  aws_region            = var.aws_region
  lambda_function_names = keys(local.lambda_functions)
  alert_email_addresses = var.alert_email_addresses
  log_retention_days    = 7
}
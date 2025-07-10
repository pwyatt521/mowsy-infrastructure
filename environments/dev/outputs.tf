output "api_gateway_url" {
  description = "URL of the API Gateway"
  value       = module.api_gateway.api_gateway_url
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "rds_endpoint" {
  description = "RDS endpoint"
  value       = module.rds.db_instance_endpoint
  sensitive   = true
}

output "s3_uploads_bucket" {
  description = "S3 uploads bucket name"
  value       = module.s3.uploads_bucket_name
}

output "s3_backups_bucket" {
  description = "S3 backups bucket name"
  value       = module.s3.backups_bucket_name
}

output "lambda_function_names" {
  description = "Names of Lambda functions"
  value       = module.lambda.lambda_function_names
}

output "cloudwatch_dashboard_url" {
  description = "CloudWatch dashboard URL"
  value       = module.monitoring.cloudwatch_dashboard_url
}

output "db_secret_name" {
  description = "Database secret name"
  value       = module.rds.db_secret_name
}

output "app_secrets_name" {
  description = "Application secrets name"
  value       = module.secrets.app_secrets_name
}
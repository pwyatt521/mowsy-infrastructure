output "app_secrets_arn" {
  description = "ARN of the app secrets"
  value       = aws_secretsmanager_secret.app_secrets.arn
}

output "app_secrets_name" {
  description = "Name of the app secrets"
  value       = aws_secretsmanager_secret.app_secrets.name
}

output "stripe_secrets_arn" {
  description = "ARN of the Stripe secrets"
  value       = aws_secretsmanager_secret.stripe_secrets.arn
}

output "stripe_secrets_name" {
  description = "Name of the Stripe secrets"
  value       = aws_secretsmanager_secret.stripe_secrets.name
}

output "external_apis_secrets_arn" {
  description = "ARN of the external APIs secrets"
  value       = aws_secretsmanager_secret.external_apis.arn
}

output "external_apis_secrets_name" {
  description = "Name of the external APIs secrets"
  value       = aws_secretsmanager_secret.external_apis.name
}
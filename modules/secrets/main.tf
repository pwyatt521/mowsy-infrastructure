resource "aws_secretsmanager_secret" "app_secrets" {
  name                    = "${var.environment}-mowsy-app-secrets"
  description             = "Application secrets for ${var.environment} environment"
  recovery_window_in_days = var.environment == "prod" ? 30 : 0

  tags = {
    Environment = var.environment
    Project     = "mowsy"
  }
}

resource "aws_secretsmanager_secret_version" "app_secrets" {
  secret_id = aws_secretsmanager_secret.app_secrets.id
  secret_string = jsonencode({
    jwt_secret          = var.jwt_secret
    stripe_secret_key   = var.stripe_secret_key
    stripe_webhook_secret = var.stripe_webhook_secret
    geocodio_api_key    = var.geocodio_api_key
    sendgrid_api_key    = var.sendgrid_api_key
  })
}

resource "aws_secretsmanager_secret" "stripe_secrets" {
  name                    = "${var.environment}-mowsy-stripe-secrets"
  description             = "Stripe API secrets for ${var.environment} environment"
  recovery_window_in_days = var.environment == "prod" ? 30 : 0

  tags = {
    Environment = var.environment
    Project     = "mowsy"
    Service     = "stripe"
  }
}

resource "aws_secretsmanager_secret_version" "stripe_secrets" {
  secret_id = aws_secretsmanager_secret.stripe_secrets.id
  secret_string = jsonencode({
    publishable_key = var.stripe_publishable_key
    secret_key     = var.stripe_secret_key
    webhook_secret = var.stripe_webhook_secret
  })
}

resource "aws_secretsmanager_secret" "external_apis" {
  name                    = "${var.environment}-mowsy-external-apis"
  description             = "External API keys for ${var.environment} environment"
  recovery_window_in_days = var.environment == "prod" ? 30 : 0

  tags = {
    Environment = var.environment
    Project     = "mowsy"
    Service     = "external-apis"
  }
}

resource "aws_secretsmanager_secret_version" "external_apis" {
  secret_id = aws_secretsmanager_secret.external_apis.id
  secret_string = jsonencode({
    geocodio_api_key = var.geocodio_api_key
    sendgrid_api_key = var.sendgrid_api_key
  })
}
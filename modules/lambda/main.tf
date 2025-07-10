resource "aws_iam_role" "lambda_execution_role" {
  name = "${var.environment}-mowsy-lambda-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Environment = var.environment
    Project     = "mowsy"
  }
}

resource "aws_iam_role_policy_attachment" "lambda_vpc_access" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "lambda_secrets_policy" {
  name = "${var.environment}-mowsy-lambda-secrets-policy"
  role = aws_iam_role.lambda_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "${var.secrets_manager_arn}*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_s3_policy" {
  name = "${var.environment}-mowsy-lambda-s3-policy"
  role = aws_iam_role.lambda_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${var.s3_bucket_arn}/*"
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "lambda_logs" {
  for_each = var.lambda_functions

  name              = "/aws/lambda/${var.environment}-mowsy-${each.key}"
  retention_in_days = var.log_retention_days

  tags = {
    Environment = var.environment
    Project     = "mowsy"
    Function    = each.key
  }
}

resource "aws_lambda_function" "api_functions" {
  for_each = var.lambda_functions

  filename         = each.value.filename
  function_name    = "${var.environment}-mowsy-${each.key}"
  role            = aws_iam_role.lambda_execution_role.arn
  handler         = each.value.handler
  source_code_hash = filebase64sha256(each.value.filename)
  runtime         = "go1.x"
  memory_size     = var.lambda_memory_size
  timeout         = var.lambda_timeout

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_security_group_id]
  }

  environment {
    variables = merge(
      {
        ENVIRONMENT = var.environment
        AWS_REGION  = var.aws_region
      },
      each.value.environment_variables
    )
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_vpc_access,
    aws_cloudwatch_log_group.lambda_logs
  ]

  tags = {
    Environment = var.environment
    Project     = "mowsy"
    Function    = each.key
  }
}

resource "aws_lambda_permission" "api_gateway" {
  for_each = var.lambda_functions

  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_functions[each.key].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${var.api_gateway_execution_arn}/*/*"
}

resource "aws_lambda_provisioned_concurrency_config" "api_functions" {
  for_each = var.environment == "prod" ? var.lambda_functions : {}

  function_name                     = aws_lambda_function.api_functions[each.key].function_name
  provisioned_concurrent_executions = each.value.provisioned_concurrency
  qualifier                        = aws_lambda_function.api_functions[each.key].version
}
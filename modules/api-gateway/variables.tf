variable "environment" {
  description = "Environment name (dev, stage, prod)"
  type        = string
}

variable "lambda_invoke_arns" {
  description = "Map of Lambda function invoke ARNs"
  type        = map(string)
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 14
}

variable "quota_limit" {
  description = "Monthly API request quota limit"
  type        = number
  default     = 10000
}

variable "throttle_rate_limit" {
  description = "API Gateway throttle rate limit (requests per second)"
  type        = number
  default     = 100
}

variable "throttle_burst_limit" {
  description = "API Gateway throttle burst limit"
  type        = number
  default     = 200
}
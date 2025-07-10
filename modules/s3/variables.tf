variable "environment" {
  description = "Environment name (dev, stage, prod)"
  type        = string
}

variable "enable_versioning" {
  description = "Enable S3 bucket versioning"
  type        = bool
  default     = false
}

variable "cors_allowed_origins" {
  description = "List of allowed origins for CORS"
  type        = list(string)
  default     = ["*"]
}

variable "object_expiration_days" {
  description = "Number of days after which objects expire"
  type        = number
  default     = 365
}

variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 2555
}
output "lambda_function_arns" {
  description = "ARNs of the Lambda functions"
  value       = { for k, v in aws_lambda_function.api_functions : k => v.arn }
}

output "lambda_function_names" {
  description = "Names of the Lambda functions"
  value       = { for k, v in aws_lambda_function.api_functions : k => v.function_name }
}

output "lambda_function_invoke_arns" {
  description = "Invoke ARNs of the Lambda functions"
  value       = { for k, v in aws_lambda_function.api_functions : k => v.invoke_arn }
}

output "lambda_execution_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda_execution_role.arn
}
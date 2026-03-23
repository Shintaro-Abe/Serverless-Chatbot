################################################################################
# Networking
################################################################################

output "vpc_id" {
  description = "VPC ID"
  value       = module.networking.vpc_id
}

output "private_subnet_ids" {
  description = "プライベートサブネット ID"
  value       = module.networking.private_subnet_ids
}

################################################################################
# Compute
################################################################################

output "lambda_function_name" {
  description = "Lambda 関数名"
  value       = module.compute.lambda_function_name
}

output "lambda_function_arn" {
  description = "Lambda 関数 ARN"
  value       = module.compute.lambda_function_arn
}

################################################################################
# API Gateway
################################################################################

output "api_gateway_invoke_url" {
  description = "API Gateway Invoke URL"
  value       = module.api.api_gateway_invoke_url
}

output "api_key_id" {
  description = "API Key ID"
  value       = module.api.api_key_id
}

output "api_key_secret_arn" {
  description = "API Key Secrets Manager ARN"
  value       = module.api.api_key_secret_arn
}

################################################################################
# Storage
################################################################################

output "dynamodb_table_name" {
  description = "DynamoDB テーブル名"
  value       = module.storage.dynamodb_table_name
}

################################################################################
# Monitoring
################################################################################

output "sns_topic_arn" {
  description = "アラート SNS トピック ARN"
  value       = module.monitoring.sns_topic_arn
}

output "dashboard_name" {
  description = "CloudWatch Dashboard 名"
  value       = module.monitoring.dashboard_name
}

output "bedrock_model_id" {
  description = "Bedrock モデル ID"
  value       = var.bedrock_model_id
}

output "bedrock_model_arn" {
  description = "Bedrock モデル ARN"
  value       = local.bedrock_model_arn
}

output "api_gateway_id" {
  description = "API Gateway REST API ID"
  value       = aws_api_gateway_rest_api.main.id
}

output "api_gateway_invoke_url" {
  description = "API Gateway のステージ Invoke URL"
  value       = aws_api_gateway_stage.main.invoke_url
}

output "api_gateway_stage_name" {
  description = "API Gateway ステージ名"
  value       = aws_api_gateway_stage.main.stage_name
}

output "api_key_id" {
  description = "API Key ID（API_KEY 認証の場合）"
  value       = var.api_auth_type == "API_KEY" ? aws_api_gateway_api_key.main[0].id : ""
}

output "api_key_secret_arn" {
  description = "API Key を格納した Secrets Manager シークレットの ARN"
  value       = var.api_auth_type == "API_KEY" ? aws_secretsmanager_secret.api_key[0].arn : ""
}

output "waf_web_acl_arn" {
  description = "WAF Web ACL ARN"
  value       = aws_wafv2_web_acl.api.arn
}

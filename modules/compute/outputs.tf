output "lambda_function_arn" {
  description = "Lambda 関数 ARN"
  value       = aws_lambda_function.chat_handler.arn
}

output "lambda_function_name" {
  description = "Lambda 関数名"
  value       = aws_lambda_function.chat_handler.function_name
}

output "lambda_function_invoke_arn" {
  description = "Lambda 関数 Invoke ARN（API Gateway 連携用）"
  value       = aws_lambda_function.chat_handler.invoke_arn
}

output "lambda_role_arn" {
  description = "Lambda 実行ロール ARN"
  value       = aws_iam_role.lambda_execution.arn
}

output "lambda_security_group_id" {
  description = "Lambda セキュリティグループ ID"
  value       = aws_security_group.lambda.id
}

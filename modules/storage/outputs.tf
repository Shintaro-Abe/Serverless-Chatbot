output "dynamodb_table_name" {
  description = "DynamoDB テーブル名"
  value       = aws_dynamodb_table.conversations.name
}

output "dynamodb_table_arn" {
  description = "DynamoDB テーブル ARN"
  value       = aws_dynamodb_table.conversations.arn
}

output "dynamodb_stream_arn" {
  description = "DynamoDB Streams ARN"
  value       = aws_dynamodb_table.conversations.stream_arn
}

output "deploy_bucket_id" {
  description = "Lambda デプロイパッケージ用 S3 バケット ID"
  value       = aws_s3_bucket.deploy.id
}

output "deploy_bucket_arn" {
  description = "Lambda デプロイパッケージ用 S3 バケット ARN"
  value       = aws_s3_bucket.deploy.arn
}

output "documents_bucket_id" {
  description = "RAG ドキュメント用 S3 バケット ID"
  value       = aws_s3_bucket.documents.id
}

output "documents_bucket_arn" {
  description = "RAG ドキュメント用 S3 バケット ARN"
  value       = aws_s3_bucket.documents.arn
}

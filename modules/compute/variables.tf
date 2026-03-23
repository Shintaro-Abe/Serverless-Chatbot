variable "environment" {
  description = "環境名 (dev/stg/prod)"
  type        = string
}

variable "project_name" {
  description = "プロジェクト名"
  type        = string
  default     = "ai-app"
}

variable "aws_region" {
  description = "AWS リージョン"
  type        = string
  default     = "ap-northeast-1"
}

variable "bedrock_model_id" {
  description = "Bedrock モデル ID"
  type        = string
}

variable "bedrock_model_arn" {
  description = "Bedrock モデル ARN（ai モジュールから取得）"
  type        = string
}

variable "dynamodb_table_name" {
  description = "DynamoDB テーブル名"
  type        = string
  default     = ""
}

variable "dynamodb_table_arn" {
  description = "DynamoDB テーブル ARN"
  type        = string
  default     = ""
}

variable "enable_dynamodb_access" {
  description = "DynamoDB アクセスポリシーを有効化するか"
  type        = bool
  default     = false
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnet_ids" {
  description = "プライベートサブネット ID のリスト"
  type        = list(string)
}

variable "vpc_cidr_block" {
  description = "VPC CIDR ブロック"
  type        = string
}

variable "bedrock_endpoint_security_group_id" {
  description = "Bedrock VPC Endpoint のセキュリティグループ ID"
  type        = string
}

variable "lambda_memory_size" {
  description = "Lambda メモリサイズ (MB)"
  type        = number
  default     = 512
}

variable "lambda_timeout" {
  description = "Lambda タイムアウト (秒)"
  type        = number
  default     = 30
}

variable "tags" {
  description = "追加タグ"
  type        = map(string)
  default     = {}
}

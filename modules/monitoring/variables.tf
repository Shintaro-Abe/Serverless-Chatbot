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

# --- 監視対象リソース ---

variable "lambda_function_name" {
  description = "監視対象の Lambda 関数名"
  type        = string
}

variable "api_gateway_id" {
  description = "監視対象の API Gateway REST API ID"
  type        = string
}

variable "api_gateway_stage_name" {
  description = "監視対象の API Gateway ステージ名"
  type        = string
}

variable "dynamodb_table_name" {
  description = "監視対象の DynamoDB テーブル名"
  type        = string
}

variable "bedrock_model_id" {
  description = "監視対象の Bedrock モデル ID"
  type        = string
}

# --- SNS ---

variable "alert_email" {
  description = "アラート通知先メールアドレス"
  type        = string
}

# --- アラーム閾値 ---

variable "lambda_error_rate_threshold" {
  description = "Lambda エラー率閾値 (%)"
  type        = number
  default     = 5
}

variable "lambda_duration_p99_threshold" {
  description = "Lambda 実行時間 p99 閾値 (ミリ秒)"
  type        = number
  default     = 25000
}

variable "api_5xx_threshold" {
  description = "API Gateway 5xx エラー回数閾値 (5分間)"
  type        = number
  default     = 10
}

variable "dynamodb_throttle_threshold" {
  description = "DynamoDB ThrottledRequests 閾値"
  type        = number
  default     = 0
}

variable "tags" {
  description = "追加タグ"
  type        = map(string)
  default     = {}
}

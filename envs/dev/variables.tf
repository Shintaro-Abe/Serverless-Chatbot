variable "aws_region" {
  description = "AWS リージョン"
  type        = string
  default     = "ap-northeast-1"
}

variable "environment" {
  description = "環境名 (dev/stg/prod)"
  type        = string
}

variable "cost_center" {
  description = "コストセンター"
  type        = string
}

variable "bedrock_model_id" {
  description = "Bedrock モデル ID"
  type        = string
}

variable "alert_email" {
  description = "アラート通知先メールアドレス"
  type        = string
}

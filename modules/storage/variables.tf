variable "environment" {
  description = "環境名 (dev/stg/prod)"
  type        = string
}

variable "project_name" {
  description = "プロジェクト名"
  type        = string
  default     = "ai-app"
}

# --- DynamoDB ---

variable "dynamodb_billing_mode" {
  description = "DynamoDB 課金モード (PAY_PER_REQUEST | PROVISIONED)"
  type        = string
  default     = "PAY_PER_REQUEST"

  validation {
    condition     = contains(["PAY_PER_REQUEST", "PROVISIONED"], var.dynamodb_billing_mode)
    error_message = "dynamodb_billing_mode は PAY_PER_REQUEST または PROVISIONED を指定してください。"
  }
}

variable "dynamodb_read_capacity" {
  description = "DynamoDB 読み取りキャパシティユニット（PROVISIONED モード時のみ）"
  type        = number
  default     = 5
}

variable "dynamodb_write_capacity" {
  description = "DynamoDB 書き込みキャパシティユニット（PROVISIONED モード時のみ）"
  type        = number
  default     = 5
}

variable "dynamodb_ttl_enabled" {
  description = "DynamoDB TTL を有効化するか"
  type        = bool
  default     = true
}

# --- S3 ---

variable "document_lifecycle_glacier_days" {
  description = "ドキュメントバケットの Glacier Instant Retrieval 移行日数"
  type        = number
  default     = 90
}

variable "tags" {
  description = "追加タグ"
  type        = map(string)
  default     = {}
}

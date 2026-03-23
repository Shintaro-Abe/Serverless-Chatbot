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
  description = "Bedrock モデル ID（例: anthropic.claude-sonnet-4-20250514）"
  type        = string
}

# --- Knowledge Base 用 placeholder（Phase 将来） ---

variable "enable_knowledge_base" {
  description = "Knowledge Base を有効化するか（将来実装）"
  type        = bool
  default     = false
}

variable "knowledge_base_s3_bucket_arn" {
  description = "Knowledge Base 用データソース S3 バケット ARN（将来実装）"
  type        = string
  default     = ""
}

variable "knowledge_base_embedding_model_id" {
  description = "Knowledge Base 用 Embedding モデル ID（将来実装）"
  type        = string
  default     = "amazon.titan-embed-text-v2:0"
}

variable "tags" {
  description = "追加タグ"
  type        = map(string)
  default     = {}
}

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

variable "lambda_function_invoke_arn" {
  description = "Lambda 関数の Invoke ARN"
  type        = string
}

variable "lambda_function_name" {
  description = "Lambda 関数名（権限付与用）"
  type        = string
}

# --- 認証 ---

variable "api_auth_type" {
  description = "認証方式 (API_KEY | COGNITO)"
  type        = string
  default     = "API_KEY"

  validation {
    condition     = contains(["API_KEY", "COGNITO"], var.api_auth_type)
    error_message = "api_auth_type は API_KEY または COGNITO を指定してください。"
  }
}

variable "cognito_user_pool_arn" {
  description = "Cognito User Pool ARN（api_auth_type=COGNITO の場合に必須）"
  type        = string
  default     = ""
}

# --- CORS ---

variable "cors_allow_origins" {
  description = "CORS 許可オリジンのリスト"
  type        = list(string)
  default     = ["*"]
}

# --- Usage Plan ---

variable "throttle_rate_limit" {
  description = "API Key スロットル: リクエスト/秒"
  type        = number
  default     = 100
}

variable "throttle_burst_limit" {
  description = "API Key スロットル: バースト上限"
  type        = number
  default     = 200
}

variable "quota_limit" {
  description = "API Key クォータ: リクエスト/日"
  type        = number
  default     = 10000
}

# --- WAF ---

variable "waf_rate_limit" {
  description = "WAF Rate-based Rule: 同一 IP の 5 分間リクエスト上限"
  type        = number
  default     = 300
}

variable "waf_body_size_limit" {
  description = "WAF Body サイズ制限 (bytes)"
  type        = number
  default     = 8192
}

# --- ログ ---

variable "access_log_retention_days" {
  description = "アクセスログ保持期間（日）"
  type        = number
  default     = 90
}

variable "secret_read_principal_arns" {
  description = "Secrets Manager の API Key シークレットを読み取れる IAM プリンシパル ARN のリスト"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "追加タグ"
  type        = map(string)
  default     = {}
}

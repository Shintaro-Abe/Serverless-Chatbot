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

variable "vpc_cidr" {
  description = "VPC の CIDR ブロック"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "パブリックサブネットの CIDR リスト"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "プライベートサブネットの CIDR リスト"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "availability_zones" {
  description = "使用する AZ のリスト"
  type        = list(string)
  default     = ["ap-northeast-1a", "ap-northeast-1c"]
}

variable "enable_flow_log" {
  description = "VPC フローログを有効化するか"
  type        = bool
  default     = true
}

variable "flow_log_retention_days" {
  description = "フローログ S3 バケットの保持期間（日）"
  type        = number
  default     = 90
}

variable "tags" {
  description = "追加タグ"
  type        = map(string)
  default     = {}
}

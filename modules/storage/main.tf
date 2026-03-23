################################################################################
# Data Sources
################################################################################

data "aws_caller_identity" "current" {}

locals {
  table_name = "${var.environment}-${var.project_name}-conversations"
}

################################################################################
# DynamoDB — conversations テーブル
################################################################################

resource "aws_dynamodb_table" "conversations" {
  name         = local.table_name
  billing_mode = var.dynamodb_billing_mode

  # PROVISIONED モード時のみキャパシティを設定
  read_capacity  = var.dynamodb_billing_mode == "PROVISIONED" ? var.dynamodb_read_capacity : null
  write_capacity = var.dynamodb_billing_mode == "PROVISIONED" ? var.dynamodb_write_capacity : null

  hash_key  = "user_id"
  range_key = "conversation_id"

  attribute {
    name = "user_id"
    type = "S"
  }

  attribute {
    name = "conversation_id"
    type = "S"
  }

  # GSI: conversation_id-index
  global_secondary_index {
    name            = "conversation_id-index"
    hash_key        = "conversation_id"
    projection_type = "ALL"

    read_capacity  = var.dynamodb_billing_mode == "PROVISIONED" ? var.dynamodb_read_capacity : null
    write_capacity = var.dynamodb_billing_mode == "PROVISIONED" ? var.dynamodb_write_capacity : null
  }

  # TTL
  ttl {
    attribute_name = var.dynamodb_ttl_enabled ? "expires_at" : ""
    enabled        = var.dynamodb_ttl_enabled
  }

  # Point-in-Time Recovery
  point_in_time_recovery {
    enabled = true
  }

  # 暗号化（AWS Managed Key）
  server_side_encryption {
    enabled = true
  }

  # DynamoDB Streams
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  tags = merge(var.tags, {
    Name = local.table_name
  })
}

################################################################################
# S3 バケット — Lambda デプロイパッケージ
################################################################################

resource "aws_s3_bucket" "deploy" {
  bucket = "${var.environment}-${var.project_name}-deploy-${data.aws_caller_identity.current.account_id}"

  tags = merge(var.tags, {
    Name = "${var.environment}-${var.project_name}-deploy"
  })
}

resource "aws_s3_bucket_versioning" "deploy" {
  bucket = aws_s3_bucket.deploy.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "deploy" {
  bucket = aws_s3_bucket.deploy.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "deploy" {
  bucket = aws_s3_bucket.deploy.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

################################################################################
# S3 バケット — RAG ドキュメント（将来の Knowledge Base 連携用）
################################################################################

resource "aws_s3_bucket" "documents" {
  bucket = "${var.environment}-${var.project_name}-documents-${data.aws_caller_identity.current.account_id}"

  tags = merge(var.tags, {
    Name = "${var.environment}-${var.project_name}-documents"
  })
}

resource "aws_s3_bucket_versioning" "documents" {
  bucket = aws_s3_bucket.documents.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "documents" {
  bucket = aws_s3_bucket.documents.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "documents" {
  bucket = aws_s3_bucket.documents.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "documents" {
  bucket = aws_s3_bucket.documents.id

  rule {
    id     = "glacier-transition"
    status = "Enabled"

    transition {
      days          = var.document_lifecycle_glacier_days
      storage_class = "GLACIER_IR"
    }
  }
}

################################################################################
# VPC — terraform-aws-modules/vpc/aws v6.6.0
################################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.6.0"

  name = "${var.environment}-${var.project_name}-vpc"
  cidr = var.vpc_cidr
  azs  = var.availability_zones

  public_subnets  = var.public_subnet_cidrs
  private_subnets = var.private_subnet_cidrs

  # NAT Gateway: 全サービスが VPC Endpoint 経由のため不要
  enable_nat_gateway = false

  # DNS
  enable_dns_hostnames = true
  enable_dns_support   = true

  # VPC フローログ
  enable_flow_log                      = var.enable_flow_log
  create_flow_log_cloudwatch_log_group = false
  create_flow_log_cloudwatch_iam_role  = false
  flow_log_destination_type            = "s3"
  flow_log_destination_arn             = aws_s3_bucket.flow_log.arn
  flow_log_file_format                 = "parquet"
  flow_log_max_aggregation_interval    = 60
  flow_log_per_hour_partition          = true
  flow_log_traffic_type                = "ALL"

  tags = merge(var.tags, {
    Module = "networking"
  })
}

################################################################################
# VPC フローログ用 S3 バケット
################################################################################

resource "aws_s3_bucket" "flow_log" {
  bucket = "${var.environment}-${var.project_name}-vpc-flow-logs-${data.aws_caller_identity.current.account_id}"

  tags = merge(var.tags, {
    Name = "${var.environment}-${var.project_name}-vpc-flow-logs"
  })
}

resource "aws_s3_bucket_lifecycle_configuration" "flow_log" {
  bucket = aws_s3_bucket.flow_log.id

  rule {
    id     = "expire-flow-logs"
    status = "Enabled"

    expiration {
      days = var.flow_log_retention_days
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "flow_log" {
  bucket = aws_s3_bucket.flow_log.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "flow_log" {
  bucket = aws_s3_bucket.flow_log.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "flow_log" {
  bucket = aws_s3_bucket.flow_log.id
  policy = data.aws_iam_policy_document.flow_log_bucket.json
}

data "aws_iam_policy_document" "flow_log_bucket" {
  statement {
    sid    = "AWSLogDeliveryWrite"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }

    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.flow_log.arn}/*"]

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  statement {
    sid    = "AWSLogDeliveryAclCheck"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }

    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.flow_log.arn]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

################################################################################
# Gateway 型 VPC Endpoints (S3, DynamoDB)
################################################################################

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = module.vpc.private_route_table_ids

  tags = merge(var.tags, {
    Name = "${var.environment}-${var.project_name}-vpce-s3"
  })
}

resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = module.vpc.private_route_table_ids

  tags = merge(var.tags, {
    Name = "${var.environment}-${var.project_name}-vpce-dynamodb"
  })
}

################################################################################
# Interface 型 VPC Endpoints 用セキュリティグループ
################################################################################

resource "aws_security_group" "vpc_endpoints" {
  name_prefix = "${var.environment}-${var.project_name}-vpce-"
  description = "Security group for VPC Interface Endpoints"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.environment}-${var.project_name}-vpce-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

################################################################################
# Interface 型 VPC Endpoints
################################################################################

# Bedrock Runtime
resource "aws_vpc_endpoint" "bedrock_runtime" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.bedrock-runtime"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(var.tags, {
    Name = "${var.environment}-${var.project_name}-vpce-bedrock-runtime"
  })
}

# CloudWatch Logs
resource "aws_vpc_endpoint" "logs" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(var.tags, {
    Name = "${var.environment}-${var.project_name}-vpce-logs"
  })
}

################################################################################
# Data Sources
################################################################################

data "aws_caller_identity" "current" {}

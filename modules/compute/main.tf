################################################################################
# Data Sources
################################################################################

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  function_name = "${var.environment}-${var.project_name}-chat-handler"
  account_id    = data.aws_caller_identity.current.account_id
  partition     = data.aws_partition.current.partition
}

################################################################################
# Lambda Layer — boto3 最新版
################################################################################

resource "terraform_data" "build_boto3_layer" {
  triggers_replace = [timestamp()]

  provisioner "local-exec" {
    command = <<-EOT
      LAYER_DIR="/tmp/boto3-layer/python"
      rm -rf /tmp/boto3-layer
      mkdir -p "$LAYER_DIR"
      pip3 install --quiet --target "$LAYER_DIR" boto3 --upgrade
      cd /tmp/boto3-layer && zip -q -r /tmp/boto3-layer.zip python/
    EOT
  }
}

resource "aws_lambda_layer_version" "boto3" {
  layer_name          = "${var.environment}-${var.project_name}-boto3-latest"
  filename            = "/tmp/boto3-layer.zip"
  compatible_runtimes = ["python3.12"]
  description         = "Latest boto3 for Bedrock API"

  depends_on = [terraform_data.build_boto3_layer]
}

################################################################################
# Lambda 関数
################################################################################

data "archive_file" "chat_handler" {
  type        = "zip"
  output_path = "/tmp/chat-handler.zip"

  source {
    content  = <<-PYTHON
import json
import os
import traceback
import boto3

bedrock_runtime = boto3.client("bedrock-runtime")
dynamodb = boto3.resource("dynamodb")

MODEL_ID = os.environ["BEDROCK_MODEL_ID"]
TABLE_NAME = os.environ.get("DYNAMODB_TABLE_NAME", "")

HEADERS = {
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": "*",
}


def handler(event, context):
    """Chat handler - invokes Bedrock and stores conversation."""
    try:
        raw_body = event.get("body") or "{}"
        body = json.loads(raw_body)
    except (json.JSONDecodeError, TypeError):
        return {
            "statusCode": 400,
            "headers": HEADERS,
            "body": json.dumps({"error": "Invalid JSON in request body"}),
        }

    user_message = body.get("message", "")
    if not user_message:
        return {
            "statusCode": 400,
            "headers": HEADERS,
            "body": json.dumps({"error": "message field is required"}),
        }

    try:
        response = bedrock_runtime.invoke_model(
            modelId=MODEL_ID,
            contentType="application/json",
            accept="application/json",
            body=json.dumps({
                "anthropic_version": "bedrock-2023-05-31",
                "max_tokens": 4096,
                "messages": [{"role": "user", "content": user_message}],
            }),
        )
        result = json.loads(response["body"].read())
    except Exception as e:
        print(f"Bedrock invocation error: {traceback.format_exc()}")
        return {
            "statusCode": 500,
            "headers": HEADERS,
            "body": json.dumps({"error": "Failed to invoke AI model"}),
        }

    return {
        "statusCode": 200,
        "headers": HEADERS,
        "body": json.dumps(result),
    }
    PYTHON
    filename = "index.py"
  }
}

resource "aws_lambda_function" "chat_handler" {
  function_name = local.function_name
  role          = aws_iam_role.lambda_execution.arn
  handler       = "index.handler"
  runtime       = "python3.12"
  memory_size   = var.lambda_memory_size
  timeout       = var.lambda_timeout

  filename         = data.archive_file.chat_handler.output_path
  source_code_hash = data.archive_file.chat_handler.output_base64sha256

  layers = [aws_lambda_layer_version.boto3.arn]

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.lambda.id]
  }

  tracing_config {
    mode = "Active"
  }

  environment {
    variables = {
      BEDROCK_MODEL_ID    = var.bedrock_model_id
      DYNAMODB_TABLE_NAME = var.dynamodb_table_name
    }
  }

  tags = merge(var.tags, {
    Name = local.function_name
  })
}

################################################################################
# CloudWatch Log Group
################################################################################

resource "aws_cloudwatch_log_group" "chat_handler" {
  name              = "/aws/lambda/${local.function_name}"
  retention_in_days = 90
}

################################################################################
# Lambda セキュリティグループ
################################################################################

resource "aws_security_group" "lambda" {
  name_prefix = "${var.environment}-${var.project_name}-lambda-"
  description = "Security group for chat-handler Lambda"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.environment}-${var.project_name}-lambda-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Lambda → Bedrock VPC Endpoint への HTTPS
resource "aws_security_group_rule" "lambda_to_bedrock_endpoint" {
  type                     = "egress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.lambda.id
  source_security_group_id = var.bedrock_endpoint_security_group_id
  description              = "HTTPS to Bedrock VPC Endpoint"
}

# Lambda → 一般 HTTPS（DynamoDB/S3 Gateway Endpoint 経由）
resource "aws_security_group_rule" "lambda_to_https" {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.lambda.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "HTTPS to AWS services via Gateway Endpoints"
}

# Bedrock Endpoint SG: Lambda SG からのインバウンド HTTPS を許可
resource "aws_security_group_rule" "bedrock_endpoint_from_lambda" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = var.bedrock_endpoint_security_group_id
  source_security_group_id = aws_security_group.lambda.id
  description              = "HTTPS from Lambda to Bedrock Endpoint"
}

################################################################################
# IAM ロール
################################################################################

resource "aws_iam_role" "lambda_execution" {
  name = "${var.environment}-${var.project_name}-chat-handler-role"

  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json

  tags = merge(var.tags, {
    Name = "${var.environment}-${var.project_name}-chat-handler-role"
  })
}

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    sid     = "LambdaAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

################################################################################
# IAM ポリシー — Bedrock InvokeModel
################################################################################

resource "aws_iam_role_policy" "bedrock_invoke" {
  name   = "${var.environment}-${var.project_name}-bedrock-invoke"
  role   = aws_iam_role.lambda_execution.id
  policy = data.aws_iam_policy_document.bedrock_invoke.json
}

data "aws_iam_policy_document" "bedrock_invoke" {
  statement {
    sid    = "AllowBedrockInvokeModel"
    effect = "Allow"
    actions = [
      "bedrock:InvokeModel",
    ]
    resources = [
      var.bedrock_model_arn,
      "arn:${local.partition}:bedrock:*::foundation-model/*",
    ]
  }
}

################################################################################
# IAM ポリシー — DynamoDB
################################################################################

resource "aws_iam_role_policy" "dynamodb_access" {
  count = var.enable_dynamodb_access ? 1 : 0

  name   = "${var.environment}-${var.project_name}-dynamodb-access"
  role   = aws_iam_role.lambda_execution.id
  policy = data.aws_iam_policy_document.dynamodb_access[0].json
}

data "aws_iam_policy_document" "dynamodb_access" {
  count = var.enable_dynamodb_access ? 1 : 0

  statement {
    sid    = "AllowDynamoDBReadWrite"
    effect = "Allow"
    actions = [
      "dynamodb:PutItem",
      "dynamodb:GetItem",
      "dynamodb:Query",
    ]
    resources = [
      var.dynamodb_table_arn,
      "${var.dynamodb_table_arn}/index/*",
    ]
  }
}

################################################################################
# IAM ポリシー — CloudWatch Logs
################################################################################

resource "aws_iam_role_policy" "cloudwatch_logs" {
  name   = "${var.environment}-${var.project_name}-cloudwatch-logs"
  role   = aws_iam_role.lambda_execution.id
  policy = data.aws_iam_policy_document.cloudwatch_logs.json
}

data "aws_iam_policy_document" "cloudwatch_logs" {
  statement {
    sid    = "AllowCloudWatchLogGroupCreation"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
    ]
    resources = [
      "arn:${local.partition}:logs:${var.aws_region}:${local.account_id}:*",
    ]
  }

  statement {
    sid    = "AllowCloudWatchLogStreaming"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = [
      "arn:${local.partition}:logs:${var.aws_region}:${local.account_id}:log-group:/aws/lambda/${local.function_name}:*",
    ]
  }
}

################################################################################
# IAM ポリシー — VPC ネットワークインターフェース
################################################################################

resource "aws_iam_role_policy" "vpc_network_interface" {
  name   = "${var.environment}-${var.project_name}-vpc-eni"
  role   = aws_iam_role.lambda_execution.id
  policy = data.aws_iam_policy_document.vpc_network_interface.json
}

data "aws_iam_policy_document" "vpc_network_interface" {
  statement {
    sid    = "AllowVpcEniManagement"
    effect = "Allow"
    actions = [
      "ec2:CreateNetworkInterface",
      "ec2:DeleteNetworkInterface",
      "ec2:DescribeNetworkInterfaces",
    ]
    resources = ["*"]
  }
}

################################################################################
# IAM ポリシー — X-Ray トレーシング
################################################################################

resource "aws_iam_role_policy" "xray_tracing" {
  name   = "${var.environment}-${var.project_name}-xray-tracing"
  role   = aws_iam_role.lambda_execution.id
  policy = data.aws_iam_policy_document.xray_tracing.json
}

data "aws_iam_policy_document" "xray_tracing" {
  statement {
    sid    = "AllowXRayTraceSend"
    effect = "Allow"
    actions = [
      "xray:PutTraceSegments",
      "xray:PutTelemetryRecords",
    ]
    resources = ["*"]
  }
}

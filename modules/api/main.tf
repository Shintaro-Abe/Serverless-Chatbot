################################################################################
# Data Sources
################################################################################

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  api_name         = "${var.environment}-${var.project_name}-api"
  cors_origins     = join(",", [for o in var.cors_allow_origins : "'${o}'"])
  cors_headers     = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key'"
  cors_methods     = "'POST,OPTIONS'"
  authorization    = var.api_auth_type == "COGNITO" ? "COGNITO_USER_POOLS" : "NONE"
  api_key_required = var.api_auth_type == "API_KEY"
}

################################################################################
# API Gateway Account — CloudWatch Logs ロール設定
################################################################################

resource "aws_iam_role" "api_gateway_cloudwatch" {
  name = "${var.environment}-${var.project_name}-apigw-cloudwatch"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "ApiGatewayAssumeRole"
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "apigateway.amazonaws.com" }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "api_gateway_cloudwatch" {
  name = "${var.environment}-${var.project_name}-apigw-cloudwatch-logs"
  role = aws_iam_role.api_gateway_cloudwatch.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowCloudWatchLogs"
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams",
        "logs:PutLogEvents",
        "logs:GetLogGroupFields",
        "logs:FilterLogEvents",
      ]
      Resource = "arn:${data.aws_partition.current.partition}:logs:*:${data.aws_caller_identity.current.account_id}:*"
    }]
  })
}

resource "aws_api_gateway_account" "main" {
  cloudwatch_role_arn = aws_iam_role.api_gateway_cloudwatch.arn
}

################################################################################
# REST API
################################################################################

resource "aws_api_gateway_rest_api" "main" {
  name        = local.api_name
  description = "${var.project_name} REST API (${var.environment})"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = merge(var.tags, {
    Name = local.api_name
  })
}

################################################################################
# /chat リソース
################################################################################

resource "aws_api_gateway_resource" "chat" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "chat"
}

################################################################################
# Cognito Authorizer（COGNITO 認証の場合のみ）
################################################################################

resource "aws_api_gateway_authorizer" "cognito" {
  count = var.api_auth_type == "COGNITO" ? 1 : 0

  name            = "${var.environment}-${var.project_name}-cognito-auth"
  rest_api_id     = aws_api_gateway_rest_api.main.id
  type            = "COGNITO_USER_POOLS"
  provider_arns   = [var.cognito_user_pool_arn]
  identity_source = "method.request.header.Authorization"
}

################################################################################
# POST /chat — Lambda プロキシ統合
################################################################################

resource "aws_api_gateway_method" "chat_post" {
  rest_api_id      = aws_api_gateway_rest_api.main.id
  resource_id      = aws_api_gateway_resource.chat.id
  http_method      = "POST"
  authorization    = local.authorization
  authorizer_id    = var.api_auth_type == "COGNITO" ? aws_api_gateway_authorizer.cognito[0].id : null
  api_key_required = local.api_key_required
}

resource "aws_api_gateway_integration" "chat_post" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.chat.id
  http_method             = aws_api_gateway_method.chat_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_function_invoke_arn
}

################################################################################
# OPTIONS /chat — CORS preflight
################################################################################

resource "aws_api_gateway_method" "chat_options" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.chat.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "chat_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.chat.id
  http_method = aws_api_gateway_method.chat_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "chat_options_200" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.chat.id
  http_method = aws_api_gateway_method.chat_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "chat_options_200" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.chat.id
  http_method = aws_api_gateway_method.chat_options.http_method
  status_code = aws_api_gateway_method_response.chat_options_200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = local.cors_headers
    "method.response.header.Access-Control-Allow-Methods" = local.cors_methods
    "method.response.header.Access-Control-Allow-Origin"  = "'${var.cors_allow_origins[0]}'"
  }
}

################################################################################
# Lambda 実行権限
################################################################################

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/${aws_api_gateway_method.chat_post.http_method}${aws_api_gateway_resource.chat.path}"
}

################################################################################
# デプロイメント + ステージ
################################################################################

resource "aws_api_gateway_deployment" "main" {
  rest_api_id = aws_api_gateway_rest_api.main.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.chat.id,
      aws_api_gateway_method.chat_post.id,
      aws_api_gateway_integration.chat_post.id,
      aws_api_gateway_method.chat_options.id,
      aws_api_gateway_integration.chat_options.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "main" {
  depends_on = [aws_api_gateway_account.main]

  deployment_id        = aws_api_gateway_deployment.main.id
  rest_api_id          = aws_api_gateway_rest_api.main.id
  stage_name           = var.environment
  xray_tracing_enabled = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_access_log.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      caller         = "$context.identity.caller"
      user           = "$context.identity.user"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      resourcePath   = "$context.resourcePath"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
      errorMessage   = "$context.error.message"
    })
  }

  tags = merge(var.tags, {
    Name = "${local.api_name}-${var.environment}"
  })
}

resource "aws_api_gateway_method_settings" "all" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  stage_name  = aws_api_gateway_stage.main.stage_name
  method_path = "*/*"

  settings {
    logging_level      = "INFO"
    metrics_enabled    = true
    data_trace_enabled = false
  }
}

################################################################################
# アクセスログ — CloudWatch Logs
################################################################################

resource "aws_cloudwatch_log_group" "api_access_log" {
  name              = "/aws/apigateway/${local.api_name}"
  retention_in_days = var.access_log_retention_days

  tags = merge(var.tags, {
    Name = "${local.api_name}-access-log"
  })
}

################################################################################
# API Key + Usage Plan（API_KEY 認証の場合）
################################################################################

resource "aws_api_gateway_api_key" "main" {
  count = var.api_auth_type == "API_KEY" ? 1 : 0

  name    = "${local.api_name}-key"
  enabled = true

  tags = merge(var.tags, {
    Name = "${local.api_name}-key"
  })
}

resource "aws_api_gateway_usage_plan" "main" {
  count = var.api_auth_type == "API_KEY" ? 1 : 0

  name = "${local.api_name}-usage-plan"

  api_stages {
    api_id = aws_api_gateway_rest_api.main.id
    stage  = aws_api_gateway_stage.main.stage_name
  }

  throttle_settings {
    rate_limit  = var.throttle_rate_limit
    burst_limit = var.throttle_burst_limit
  }

  quota_settings {
    limit  = var.quota_limit
    period = "DAY"
  }

  tags = merge(var.tags, {
    Name = "${local.api_name}-usage-plan"
  })
}

resource "aws_api_gateway_usage_plan_key" "main" {
  count = var.api_auth_type == "API_KEY" ? 1 : 0

  key_id        = aws_api_gateway_api_key.main[0].id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.main[0].id
}

################################################################################
# Secrets Manager — API Key 格納
################################################################################

resource "aws_kms_key" "api_key_secret" {
  count = var.api_auth_type == "API_KEY" ? 1 : 0

  description             = "KMS key for ${var.environment}-${var.project_name} API Key secret"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = merge(var.tags, {
    Name = "${var.environment}-${var.project_name}-api-key-kms"
  })
}

resource "aws_kms_alias" "api_key_secret" {
  count = var.api_auth_type == "API_KEY" ? 1 : 0

  name          = "alias/${var.environment}-${var.project_name}-api-key-secret"
  target_key_id = aws_kms_key.api_key_secret[0].key_id
}

resource "aws_secretsmanager_secret" "api_key" {
  count = var.api_auth_type == "API_KEY" ? 1 : 0

  name        = "${var.environment}-${var.project_name}-api-key"
  description = "API Gateway API Key for ${var.environment}-${var.project_name}"
  kms_key_id  = aws_kms_key.api_key_secret[0].arn

  tags = merge(var.tags, {
    Name = "${var.environment}-${var.project_name}-api-key"
  })
}

resource "aws_secretsmanager_secret_version" "api_key" {
  count = var.api_auth_type == "API_KEY" ? 1 : 0

  secret_id     = aws_secretsmanager_secret.api_key[0].id
  secret_string = aws_api_gateway_api_key.main[0].value
}

resource "aws_secretsmanager_secret_policy" "api_key" {
  count = var.api_auth_type == "API_KEY" && length(var.secret_read_principal_arns) > 0 ? 1 : 0

  secret_arn = aws_secretsmanager_secret.api_key[0].arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowGetSecretValue"
        Effect    = "Allow"
        Action    = "secretsmanager:GetSecretValue"
        Resource  = aws_secretsmanager_secret.api_key[0].arn
        Principal = { AWS = var.secret_read_principal_arns }
      },
      {
        Sid       = "DenyAllOthers"
        Effect    = "Deny"
        Action    = "secretsmanager:GetSecretValue"
        Resource  = aws_secretsmanager_secret.api_key[0].arn
        Principal = "*"
        Condition = {
          StringNotLike = {
            "aws:PrincipalArn" = var.secret_read_principal_arns
          }
        }
      },
    ]
  })
}

################################################################################
# WAF v2 Web ACL
################################################################################

resource "aws_wafv2_web_acl" "api" {
  name        = "${local.api_name}-waf"
  scope       = "REGIONAL"
  description = "WAF for ${local.api_name}"

  default_action {
    allow {}
  }

  # Rule 1: AWS Managed Rules — Common Rule Set
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"

        # SizeRestrictions_BODY を除外（カスタムルールで制御するため）
        rule_action_override {
          name = "SizeRestrictions_BODY"
          action_to_use {
            count {}
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.environment}-${var.project_name}-aws-managed-common"
      sampled_requests_enabled   = true
    }
  }

  # Rule 2: Rate-based Rule — 同一 IP から 300 req/5min
  rule {
    name     = "RateBasedRule"
    priority = 2

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.waf_rate_limit
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.environment}-${var.project_name}-rate-limit"
      sampled_requests_enabled   = true
    }
  }

  # Rule 3: Body サイズ制限
  rule {
    name     = "BodySizeLimit"
    priority = 3

    action {
      block {}
    }

    statement {
      size_constraint_statement {
        field_to_match {
          body {
            oversize_handling = "MATCH"
          }
        }
        comparison_operator = "GT"
        size                = var.waf_body_size_limit
        text_transformation {
          priority = 0
          type     = "NONE"
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.environment}-${var.project_name}-body-size-limit"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.environment}-${var.project_name}-waf"
    sampled_requests_enabled   = true
  }

  tags = merge(var.tags, {
    Name = "${local.api_name}-waf"
  })
}

# WAF を API Gateway ステージに紐付け
resource "aws_wafv2_web_acl_association" "api" {
  resource_arn = aws_api_gateway_stage.main.arn
  web_acl_arn  = aws_wafv2_web_acl.api.arn
}

locals {
  prefix = "${var.environment}-${var.project_name}"
}

################################################################################
# SNS トピック — アラート通知
################################################################################

resource "aws_sns_topic" "alerts" {
  name = "${local.prefix}-alerts"

  tags = merge(var.tags, {
    Name = "${local.prefix}-alerts"
  })
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

################################################################################
# CloudWatch Alarm — Lambda エラー率 > 5% (5分間)
################################################################################

resource "aws_cloudwatch_metric_alarm" "lambda_error_rate" {
  alarm_name          = "${local.prefix}-lambda-error-rate"
  alarm_description   = "Lambda error rate exceeds ${var.lambda_error_rate_threshold}%"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  threshold           = var.lambda_error_rate_threshold
  treat_missing_data  = "notBreaching"

  metric_query {
    id          = "error_rate"
    expression  = "(errors / invocations) * 100"
    label       = "Error Rate (%)"
    return_data = true
  }

  metric_query {
    id = "errors"
    metric {
      metric_name = "Errors"
      namespace   = "AWS/Lambda"
      period      = 300
      stat        = "Sum"
      dimensions = {
        FunctionName = var.lambda_function_name
      }
    }
  }

  metric_query {
    id = "invocations"
    metric {
      metric_name = "Invocations"
      namespace   = "AWS/Lambda"
      period      = 300
      stat        = "Sum"
      dimensions = {
        FunctionName = var.lambda_function_name
      }
    }
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = merge(var.tags, {
    Name = "${local.prefix}-lambda-error-rate"
  })
}

################################################################################
# CloudWatch Alarm — Lambda Duration p99 > 25秒
################################################################################

resource "aws_cloudwatch_metric_alarm" "lambda_duration_p99" {
  alarm_name          = "${local.prefix}-lambda-duration-p99"
  alarm_description   = "Lambda p99 duration exceeds ${var.lambda_duration_p99_threshold}ms"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 300
  extended_statistic  = "p99"
  threshold           = var.lambda_duration_p99_threshold
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = var.lambda_function_name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = merge(var.tags, {
    Name = "${local.prefix}-lambda-duration-p99"
  })
}

################################################################################
# CloudWatch Alarm — API Gateway 5xx > 10回/5分
################################################################################

resource "aws_cloudwatch_metric_alarm" "api_5xx" {
  alarm_name          = "${local.prefix}-api-5xx"
  alarm_description   = "API Gateway 5xx errors exceed ${var.api_5xx_threshold} in 5 minutes"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "5XXError"
  namespace           = "AWS/ApiGateway"
  period              = 300
  statistic           = "Sum"
  threshold           = var.api_5xx_threshold
  treat_missing_data  = "notBreaching"

  dimensions = {
    ApiName = "${local.prefix}-api"
    Stage   = var.api_gateway_stage_name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = merge(var.tags, {
    Name = "${local.prefix}-api-5xx"
  })
}

################################################################################
# CloudWatch Alarm — DynamoDB ThrottledRequests > 0
################################################################################

resource "aws_cloudwatch_metric_alarm" "dynamodb_throttle" {
  alarm_name          = "${local.prefix}-dynamodb-throttle"
  alarm_description   = "DynamoDB throttled requests detected"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ThrottledRequests"
  namespace           = "AWS/DynamoDB"
  period              = 300
  statistic           = "Sum"
  threshold           = var.dynamodb_throttle_threshold
  treat_missing_data  = "notBreaching"

  dimensions = {
    TableName = var.dynamodb_table_name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = merge(var.tags, {
    Name = "${local.prefix}-dynamodb-throttle"
  })
}

################################################################################
# X-Ray トレーシング
# Lambda: tracing_config は compute モジュールで Active に設定済み
# API Gateway: ステージの xray_tracing_enabled で有効化
################################################################################

resource "aws_xray_sampling_rule" "main" {
  rule_name      = "${local.prefix}-sampling"
  priority       = 1000
  version        = 1
  reservoir_size = 1
  fixed_rate     = 0.05
  url_path       = "*"
  host           = "*"
  http_method    = "*"
  service_type   = "*"
  service_name   = "*"
  resource_arn   = "*"

  tags = merge(var.tags, {
    Name = "${local.prefix}-xray-sampling"
  })
}

################################################################################
# CloudWatch Dashboard
################################################################################

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${local.prefix}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      # Row 1: Lambda メトリクス
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "Lambda - Invocations & Errors"
          region  = var.aws_region
          view    = "timeSeries"
          stacked = false
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", var.lambda_function_name, { stat = "Sum" }],
            ["AWS/Lambda", "Errors", "FunctionName", var.lambda_function_name, { stat = "Sum", color = "#d62728" }],
          ]
          period = 300
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "Lambda - Duration (p50 / p99)"
          region  = var.aws_region
          view    = "timeSeries"
          stacked = false
          metrics = [
            ["AWS/Lambda", "Duration", "FunctionName", var.lambda_function_name, { stat = "p50", label = "p50" }],
            ["AWS/Lambda", "Duration", "FunctionName", var.lambda_function_name, { stat = "p99", label = "p99", color = "#d62728" }],
          ]
          period = 300
        }
      },

      # Row 2: API Gateway メトリクス
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "API Gateway - Requests & Errors"
          region  = var.aws_region
          view    = "timeSeries"
          stacked = false
          metrics = [
            ["AWS/ApiGateway", "Count", "ApiName", "${local.prefix}-api", "Stage", var.api_gateway_stage_name, { stat = "Sum" }],
            ["AWS/ApiGateway", "4XXError", "ApiName", "${local.prefix}-api", "Stage", var.api_gateway_stage_name, { stat = "Sum", color = "#ff9900" }],
            ["AWS/ApiGateway", "5XXError", "ApiName", "${local.prefix}-api", "Stage", var.api_gateway_stage_name, { stat = "Sum", color = "#d62728" }],
          ]
          period = 300
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "API Gateway - Latency"
          region  = var.aws_region
          view    = "timeSeries"
          stacked = false
          metrics = [
            ["AWS/ApiGateway", "Latency", "ApiName", "${local.prefix}-api", "Stage", var.api_gateway_stage_name, { stat = "p50", label = "p50" }],
            ["AWS/ApiGateway", "Latency", "ApiName", "${local.prefix}-api", "Stage", var.api_gateway_stage_name, { stat = "p99", label = "p99", color = "#d62728" }],
          ]
          period = 300
        }
      },

      # Row 3: DynamoDB メトリクス
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6
        properties = {
          title   = "DynamoDB - Consumed RCU / WCU"
          region  = var.aws_region
          view    = "timeSeries"
          stacked = false
          metrics = [
            ["AWS/DynamoDB", "ConsumedReadCapacityUnits", "TableName", var.dynamodb_table_name, { stat = "Sum" }],
            ["AWS/DynamoDB", "ConsumedWriteCapacityUnits", "TableName", var.dynamodb_table_name, { stat = "Sum", color = "#ff9900" }],
          ]
          period = 300
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 12
        width  = 12
        height = 6
        properties = {
          title   = "DynamoDB - ThrottledRequests"
          region  = var.aws_region
          view    = "timeSeries"
          stacked = false
          metrics = [
            ["AWS/DynamoDB", "ThrottledRequests", "TableName", var.dynamodb_table_name, { stat = "Sum", color = "#d62728" }],
          ]
          period = 300
        }
      },

      # Row 4: Bedrock メトリクス（カスタムメトリクス）
      {
        type   = "metric"
        x      = 0
        y      = 18
        width  = 12
        height = 6
        properties = {
          title   = "Bedrock - Invocation Count"
          region  = var.aws_region
          view    = "timeSeries"
          stacked = false
          metrics = [
            ["AWS/Bedrock", "Invocations", "ModelId", var.bedrock_model_id, { stat = "Sum" }],
          ]
          period = 300
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 18
        width  = 12
        height = 6
        properties = {
          title   = "Bedrock - Invocation Latency"
          region  = var.aws_region
          view    = "timeSeries"
          stacked = false
          metrics = [
            ["AWS/Bedrock", "InvocationLatency", "ModelId", var.bedrock_model_id, { stat = "p50", label = "p50" }],
            ["AWS/Bedrock", "InvocationLatency", "ModelId", var.bedrock_model_id, { stat = "p99", label = "p99", color = "#d62728" }],
          ]
          period = 300
        }
      },
    ]
  })
}

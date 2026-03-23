output "sns_topic_arn" {
  description = "アラート SNS トピック ARN"
  value       = aws_sns_topic.alerts.arn
}

output "dashboard_name" {
  description = "CloudWatch Dashboard 名"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}

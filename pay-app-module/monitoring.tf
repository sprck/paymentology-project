# SNS Topic for Alerts 
resource "aws_sns_topic" "sns_alerts_pay_app" {
  name = "${var.app_name}-alerts-topic"
  kms_master_key_id = aws_kms_key.pay_app_kms.id

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-alerts-topic"
    }
  )
}

# SNS Email Subscription 
resource "aws_sns_topic_subscription" "email_alerts_pay_app" {
  topic_arn = aws_sns_topic.sns_alerts_pay_app.arn
  protocol  = "email"
  endpoint  = var.alert_email

}

resource "aws_cloudtrail" "cloudtrail_pay_app" {
  name                          = "${var.app_name}-trail"
  s3_bucket_name                = aws_s3_bucket.s3_logs_pay_app.id
  s3_key_prefix                 = "cloudtrail"
  is_multi_region_trail         = true
  include_global_service_events = true
  enable_log_file_validation    = true
  kms_key_id                    = aws_kms_key.pay_app_kms.arn

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-trail"
    }
  )

  depends_on = [ aws_s3_bucket_policy.s3_logs_pay_app ]
}

# CloudWatch Alarms
# Alarm for High CPU Utilization

resource "aws_cloudwatch_metric_alarm" "cpu_utilization_pay_app" {
  alarm_name          = "${var.app_name}-high-cpu-utilization"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300" 
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors EC2 CPU utilization for the ASG."
  alarm_actions       = [aws_sns_topic.sns_alerts_pay_app.arn]
  ok_actions          = [aws_sns_topic.sns_alerts_pay_app.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.asg-pay_app.name
  }
}

# Alarm for High Memory Usage (from CloudWatch Agent)
resource "aws_cloudwatch_metric_alarm" "memory_usage_pay_app" {
  alarm_name          = "${var.app_name}-high-memory-usage"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "mem_used_percent"
  namespace           = "CWAgent"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors EC2 memory usage for the ASG."
  alarm_actions       = [aws_sns_topic.sns_alerts_pay_app.arn]
  ok_actions          = [aws_sns_topic.sns_alerts_pay_app.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.asg-pay_app.name
  }
}

# Alarm for High Disk Usage (from CloudWatch Agent)
resource "aws_cloudwatch_metric_alarm" "disk_usage_pay_app" {
  alarm_name          = "${var.app_name}-high-disk-usage"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "disk_used_percent"
  namespace           = "CWAgent"
  period              = "300"
  statistic           = "Average"
  threshold           = "85" 
  alarm_description   = "This metric monitors EC2 root disk usage for the ASG."
  alarm_actions       = [aws_sns_topic.sns_alerts_pay_app.arn]
  ok_actions          = [aws_sns_topic.sns_alerts_pay_app.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.asg-pay_app.name
    path                 = "/"
  }
}

# CloudWatch Log Group for EC2 Instances
resource "aws_cloudwatch_log_group" "lg_ec2_pay_app" {
  name              = "/${var.app_name}/ec2/system-logs"
  kms_key_id = aws_kms_key.pay_app_kms.arn
  retention_in_days = 14

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-ec2-log-group"
    }
  )
}

# CloudWatch Log Group for API Gateway

resource "aws_cloudwatch_log_group" "lg_api_gw_pay_app" {
  name              = "/${var.app_name}/api-gateway/execution-logs"
  kms_key_id = aws_kms_key.pay_app_kms.arn
  retention_in_days = 14

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-api-gw-log-group"
    }
  )
}

resource "aws_cloudwatch_log_group" "cloudtrail_logs" {
  name              = "/depi-sec/cloudtrail"
  retention_in_days = 14
}

resource "aws_iam_role" "cloudtrail_cw_role" {
  name = "depi-sec-cloudtrail-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "cloudtrail.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "cloudtrail_cw_policy" {
  name = "depi-sec-cloudtrail-policy"
  role = aws_iam_role.cloudtrail_cw_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
      Effect   = "Allow"
      Resource = "${aws_cloudwatch_log_group.cloudtrail_logs.arn}:*"
    }]
  })
}

resource "aws_cloudtrail" "main_trail" {
  name                          = "depi-sec-trail"
  s3_bucket_name                = aws_s3_bucket.logs_bucket.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  cloud_watch_logs_group_arn    = "${aws_cloudwatch_log_group.cloudtrail_logs.arn}:*"
  cloud_watch_logs_role_arn     = aws_iam_role.cloudtrail_cw_role.arn

  event_selector {
    read_write_type           = "ReadOnly"
    include_management_events = true
    data_resource {
      type   = "AWS::S3::Object"
      values = ["${aws_s3_bucket.app_bucket.arn}/"]
    }
  }
  depends_on = [aws_s3_bucket_policy.logs_policy]
}

resource "aws_cloudwatch_log_group" "flowlogs" {
  name              = "/depi-sec/vpc/flowlogs"
  retention_in_days = 14
}

resource "aws_iam_role" "flowlogs_role" {
  name = "depi-sec-flowlogs-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "flowlogs_policy" {
  name = "depi-sec-flowlogs-policy"
  role = aws_iam_role.flowlogs_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action   = ["logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogGroups", "logs:DescribeLogStreams"]
      Effect   = "Allow"
      Resource = "*"
    }]
  })
}

resource "aws_flow_log" "vpc_flow_log" {
  log_destination      = aws_cloudwatch_log_group.flowlogs.arn
  iam_role_arn         = aws_iam_role.flowlogs_role.arn
  vpc_id               = aws_vpc.app_vpc.id
  traffic_type         = "ALL"
}

resource "aws_sns_topic" "alerts" {
  name = "depi-sec-alerts"
}

resource "aws_sns_topic_subscription" "email_alert" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "depi-sec-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 70
  alarm_actions       = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "unhealthy_hosts" {
  alarm_name          = "depi-sec-unhealthy-hosts"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Maximum"
  threshold           = 0
  alarm_actions       = [aws_sns_topic.alerts.arn]
  dimensions = {
    TargetGroup  = aws_lb_target_group.app_tg.arn_suffix
    LoadBalancer = aws_lb.app_alb.arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_storage_low" {
  alarm_name          = "depi-sec-rds-storage-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 2000000000 # 2 GB in bytes
  alarm_actions       = [aws_sns_topic.alerts.arn]
  dimensions = {
    DBInstanceIdentifier = aws_db_instance.mysql_db.identifier
  }
}

resource "aws_cloudwatch_log_metric_filter" "failed_login" {
  name           = "FailedConsoleLogin"
  pattern        = "{ ($.eventName = ConsoleLogin) && ($.errorMessage = \"Failed authentication\") }"
  log_group_name = aws_cloudwatch_log_group.cloudtrail_logs.name

  metric_transformation {
    name      = "FailedConsoleLogins"
    namespace = "SecurityMetrics"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "failed_login_alarm" {
  alarm_name          = "depi-sec-failed-logins"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = aws_cloudwatch_log_metric_filter.failed_login.metric_transformation[0].name
  namespace           = aws_cloudwatch_log_metric_filter.failed_login.metric_transformation[0].namespace
  period              = 300
  statistic           = "Sum"
  threshold           = 3
  alarm_actions       = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_dashboard" "overview" {
  dashboard_name = "depi-sec-overview"
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric",
        x      = 0, y = 0, width = 6, height = 6,
        properties = {
          metrics = [["AWS/EC2", "CPUUtilization"]],
          view    = "timeSeries",
          stacked = false,
          region  = var.region,
          title   = "EC2 CPU Utilization"
        }
      },
      {
        type   = "metric",
        x      = 6, y = 0, width = 6, height = 6,
        properties = {
          metrics = [["AWS/ApplicationELB", "UnHealthyHostCount", "TargetGroup", aws_lb_target_group.app_tg.arn_suffix, "LoadBalancer", aws_lb.app_alb.arn_suffix]],
          view    = "timeSeries",
          stacked = false,
          region  = var.region,
          title   = "ALB Unhealthy Hosts"
        }
      },
      {
        type   = "metric",
        x      = 0, y = 6, width = 6, height = 6,
        properties = {
          metrics = [["AWS/RDS", "FreeStorageSpace", "DBInstanceIdentifier", aws_db_instance.mysql_db.identifier]],
          view    = "timeSeries",
          stacked = false,
          region  = var.region,
          title   = "RDS Free Storage (Bytes)"
        }
      },
      {
        type   = "metric",
        x      = 6, y = 6, width = 6, height = 6,
        properties = {
          metrics = [["SecurityMetrics", "FailedConsoleLogins"]],
          view    = "timeSeries",
          stacked = false,
          region  = var.region,
          title   = "Failed Console Logins"
        }
      }
    ]
  })
}
# --- IAM Role for Lambda ---
resource "aws_iam_role" "lambda_role" {
  name = "depi-sec-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "depi-sec-lambda-policy"
  role = aws_iam_role.lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ec2:DescribeSecurityGroups",
          "ec2:RevokeSecurityGroupIngress",
          "sns:Publish",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# --- Package the Python Script ---
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "remediate.py"
  output_path = "remediate.zip"
}

# --- Lambda Function ---
resource "aws_lambda_function" "remediation_lambda" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "depi-sec-auto-remediate"
  role             = aws_iam_role.lambda_role.arn
  handler          = "remediate.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = "python3.12"
  
  environment {
    variables = {
      # Passes the SNS topic ARN from logging.tf into the Python script
      SNS_TOPIC_ARN = aws_sns_topic.alerts.arn
    }
  }
}

# --- EventBridge Rule ---
resource "aws_cloudwatch_event_rule" "sg_change_rule" {
  name        = "depi-sec-sg-change-rule"
  description = "Trigger on AuthorizeSecurityGroupIngress API calls"
  
  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    "detail-type" = ["AWS API Call via CloudTrail"]
    detail = {
      eventSource = ["ec2.amazonaws.com"]
      eventName   = ["AuthorizeSecurityGroupIngress"]
    }
  })
}

# --- EventBridge Target & Permissions ---
resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.sg_change_rule.name
  target_id = "RemediateLambdaTarget"
  arn       = aws_lambda_function.remediation_lambda.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.remediation_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.sg_change_rule.arn
}
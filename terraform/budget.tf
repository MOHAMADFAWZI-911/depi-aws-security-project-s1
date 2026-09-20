resource "aws_iam_policy" "deny_expensive" {
  name        = "depi-sec-deny-expensive"
  description = "Deny expensive EC2 and RDS creations"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Deny"
      Action   = [
        "ec2:RunInstances",
        "rds:CreateDBInstance"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_iam_role" "budgets_role" {
  name = "depi-sec-budgets-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "budgets.amazonaws.com"
      }
    }]
  })
}

resource "aws_budgets_budget" "monthly_budget" {
  name         = "depi-sec-monthly"
  budget_type  = "COST"
  limit_amount = "10.0"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  # Alert at 80% Actual
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }

  # Alert at 100% Forecasted
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.alert_email]
  }
}

resource "aws_budgets_budget_action" "deny_expensive_action" {
  budget_name         = aws_budgets_budget.monthly_budget.name
  action_type         = "APPLY_IAM_POLICY"
  approval_model      = "AUTOMATIC"
  execution_role_arn  = aws_iam_role.budgets_role.arn
  notification_type   = "ACTUAL"

  action_threshold {
    action_threshold_type  = "PERCENTAGE"
    action_threshold_value = 90
  }

  definition {
    iam_action_definition {
      policy_arn = aws_iam_policy.deny_expensive.arn
      groups     = [aws_iam_group.developers.name]
    }
  }

  subscriber {
    address           = var.alert_email
    subscription_type = "EMAIL"
  }
}
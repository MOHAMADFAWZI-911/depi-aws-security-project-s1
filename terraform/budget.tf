resource "aws_iam_policy" "deny_expensive" {
  name        = "depi-sec-deny-expensive"
  description = "Deny expensive EC2 and RDS creations"
  policy      = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Deny",
      Action = ["ec2:RunInstances", "rds:CreateDBInstance"],
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
      Principal = { Service = "budgets.amazonaws.com" }
    }]
  })
}
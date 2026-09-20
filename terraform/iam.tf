# --- 1. Account Password Policy ---
resource "aws_iam_account_password_policy" "strict" {
  minimum_password_length        = 14
  require_uppercase_characters   = true
  require_lowercase_characters   = true
  require_numbers                = true
  require_symbols                = true
  max_password_age               = 90
  allow_users_to_change_password = true
}

# --- 2. Group and Managed Policy ---
resource "aws_iam_group" "developers" {
  name = "depi-sec-developers"
}

resource "aws_iam_group_policy_attachment" "developers_readonly" {
  group      = aws_iam_group.developers.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# --- 3. User, Group Membership, and Login Profile ---
resource "aws_iam_user" "dev1" {
  name = "depi-dev-1"
}

resource "aws_iam_user_group_membership" "dev1_membership" {
  user = aws_iam_user.dev1.name
  groups = [
    aws_iam_group.developers.name
  ]
}

resource "aws_iam_user_login_profile" "dev1_login" {
  user                    = aws_iam_user.dev1.name
  password_reset_required = true
}

# --- 4. Customer Managed Policy for S3 ---
resource "aws_iam_policy" "s3_app_read" {
  name        = "depi-sec-s3-app-read"
  description = "Allow EC2 to read from the app S3 bucket"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action   = "s3:GetObject"
      Effect   = "Allow"
      # Using the dynamic reference ensures it matches the exact bucket created in storage.tf 
      # without using a generic wildcard bucket like "arn:aws:s3:::*"
      Resource = "${aws_s3_bucket.app_bucket.arn}/*"
    }]
  })
}

# --- 5. IAM Role for EC2 and Policy Attachments ---
resource "aws_iam_role" "ec2_role" {
  name = "depi-sec-ec2-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "s3_read_attach" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.s3_app_read.arn
}

# --- 6. Instance Profile ---
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "depi-sec-ec2-profile"
  role = aws_iam_role.ec2_role.name
}
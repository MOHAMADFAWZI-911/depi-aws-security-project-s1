# --- IAM Role for AWS Backup ---
resource "aws_iam_role" "backup_role" {
  name = "depi-sec-backup-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "backup.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "backup_policy" {
  role       = aws_iam_role.backup_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_iam_role_policy_attachment" "restore_policy" {
  role       = aws_iam_role.backup_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
}

# --- Backup Vault & Lock ---
resource "aws_backup_vault" "vault" {
  name = "depi-sec-vault"
  tags = { Name = "depi-sec-vault" }
}

resource "aws_backup_vault_lock_configuration" "vault_lock" {
  backup_vault_name   = aws_backup_vault.vault.name
  changeable_for_days = 3
  min_retention_days  = 7
  max_retention_days  = 365
}

# --- Backup Plan & Schedule ---
resource "aws_backup_plan" "daily_plan" {
  name = "depi-sec-daily-backup"

  rule {
    rule_name         = "daily-0500-utc"
    target_vault_name = aws_backup_vault.vault.name
    schedule          = "cron(0 5 * * ? *)"
    start_window      = 60
    
    lifecycle {
      delete_after = 30
    }
  }
  tags = { Name = "depi-sec-daily-backup" }
}

# --- Backup Selection (By Tag) ---
resource "aws_backup_selection" "project_selection" {
  iam_role_arn = aws_iam_role.backup_role.arn
  name         = "depi-sec-project-resources"
  plan_id      = aws_backup_plan.daily_plan.id

  selection_tag {
    type  = "STRINGEQUALS"
    key   = "Project"
    value = "depi-mini-project-1"
  }
}
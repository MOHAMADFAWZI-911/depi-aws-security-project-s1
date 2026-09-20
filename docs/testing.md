# Testing Log

| # | Test | What I Did | Expected Result | Actual Result |
|---|------|------------|-----------------|---------------|
| 1 | Direct ALB Access | Accessed ALB DNS via HTTP in browser | 403 Forbidden | 403 Forbidden returned |
| 2 | CloudFront Access | Accessed CloudFront domain | Page loads over HTTPS | Page loaded successfully |
| 3 | SSH to Private IP | Tried `ssh user@<private-ip>` | Timeout & REJECT in Flow Logs | Timed out |
| 4 | External RDS Connect | Tried reaching RDS from laptop | Timeout | Timed out |
| 5 | Internal RDS Connect | Ran `nc -zv <rds-endpoint> 3306` from App Server via SSM | Success | Port 3306 open |
| 6 | S3 Public Object | Attempted to make object public via Console | Refused by Block Public Access | Access Denied |
| 7 | SG Auto-Remediation | Manually added 0.0.0.0/0 on Port 22 to App SG | Removed by Lambda in <1 min, email sent | Rule deleted, alert received |
| 8 | ALB Health Checks | Stopped Nginx on Server A | Target unhealthy, site works, alarm email | Health failed, site up |
| 9 | VPC Peering Ping | Ran `curl <app-private-ip>` from Tools Server | Page returned | Page returned |
| 10 | Vault Lock Test | Tried deleting a backup recovery point | Access denied | Deletion failed |
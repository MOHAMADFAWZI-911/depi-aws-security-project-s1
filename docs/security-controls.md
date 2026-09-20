# Security Controls

| Control | AWS Service | Threat it stops | Evidence |
|---------|-------------|-----------------|----------|
| Stateful Firewall Tiering | Security Groups | Direct access to RDS or EFS from anywhere except the App Servers | ![SG Rules](../screenshots/05-security-groups/05-sg-rules.png) |
| Stateless Network Denial | Network ACLs | Misconfigured Security Groups accidentally allowing Port 22 | ![NACL Rules](../screenshots/06-nacls/06-nacl-rules.png) |
| Private Service Access | VPC Endpoints | Traffic to AWS SSM or S3 traversing the public internet | ![Endpoints](../screenshots/07-endpoints/07-endpoints-active.png) |
| IAM Least Privilege | IAM Policies | EC2 instances accessing S3 buckets they don't own | ![IAM Policy](../screenshots/03-iam/03-custom-policy.png) |
| Cost Governance | AWS Budgets | Compromised credentials spinning up expensive crypto-mining EC2s | ![Budget Action](../screenshots/02-budget/02-budget-action.png) |
| Forced HTTPS | S3 Bucket Policy | Man-in-the-middle attacks intercepting unencrypted data | *(Insert JSON here)* |
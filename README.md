# Secure AWS Web Platform (Terraform)

## 1. Project overview
This project builds a highly secure, private web platform on AWS using Terraform. It features a two-tier architecture where the web servers and database reside in private subnets with no internet access. The infrastructure is protected by a Web Application Firewall (via CloudFront), strict IAM least-privilege roles, and automated remediation using Lambda. Every action and network packet is logged, and data is protected using an immutable AWS Backup vault.

## 2. Traffic Flow Description
* **Ingress & Edge Security**: Public requests enter via Amazon CloudFront (HTTPS). CloudFront appends a custom secret header to origin requests before forwarding them to the public Application Load Balancer (`depi-sec-alb`).
* **Origin Filtering**: The ALB validates the secret header. Valid requests are forwarded to EC2 app servers in private subnets; requests directly targeting the ALB without the header are blocked with a `403 Forbidden`.
* **Compute & Data Processing**: EC2 instances in Availability Zones `us-east-1a` and `us-east-1b` process Nginx application traffic, read/write shared files on Amazon EFS (`/mnt/shared`), and query Amazon RDS MySQL (`depi-sec-rds-mysql`) over port 3306.
* **Network Isolation**: App instances have no public IP addresses and cannot be reached directly from the internet. Internal repository updates route through an S3 VPC Gateway Endpoint, and management access is handled out-of-band via AWS Systems Manager.

---

## 3. Network design table
| Subnet | CIDR | AZ | Type |
|--------|------|----|------|
| depi-sec-public-a | 10.0.1.0/24 | us-east-1a | Public |
| depi-sec-public-b | 10.0.2.0/24 | us-east-1b | Public |
| depi-sec-private-a | 10.0.11.0/24 | us-east-1a | Private |
| depi-sec-private-b | 10.0.12.0/24 | us-east-1b | Private |
| depi-sec-tools-a | 10.1.1.0/24 | us-east-1a | Private (tools VPC) |

## 4. Security controls table
| Control | AWS Service | Threat it stops |
|---------|-------------|-----------------|
| Auto-Remediation | EventBridge & Lambda | Accidental or malicious open SSH (port 22) to the internet |
| Immutable Backups | AWS Backup Vault Lock | Ransomware deleting backups before encrypting primary data |
| Private Compute | VPC, EC2 (No Public IP) | Direct internet access to application servers |
| *See docs/security-controls.md for the full list and evidence.* |

## 5. Prerequisites
* Terraform >= 1.6
* AWS CLI configured with administrator permissions
* Git (for version control)

## 6. How to deploy
1. Clone the repository.
2. Initialize Terraform: `terraform init`
3. Review the plan: `terraform plan`
4. Apply the configuration: `terraform apply` (Provide your email for alerts when prompted).

## 7. How to verify
excute the following 10 verification steps to validate the platform:

1. **CloudFront Fronting Test (200 OK)**: Access the CloudFront distribution domain. Confirm the page loads with `200 OK`.
2. **Direct ALB Access Block (403 Forbidden)**: Send a request directly to the ALB DNS name without the custom secret header. Confirm a `403 Forbidden` response.
3. **Direct EC2 Connection Prevention (No Route)**: Attempt to connect directly to private EC2 instances from a local browser/terminal. Confirm connection timeout/no route.
4. **Session Manager Login**: Connect to `depi-sec-app-a` using AWS SSM Session Manager (`aws ssm start-session --target <instance-id>`).
5. **Nginx Active Status**: From inside the SSM shell, run `curl localhost` to verify Nginx serves the local index page.
6. **Internal RDS Reachability**: From the SSM shell, execute `(echo > /dev/tcp/<rds-endpoint>/3306) && echo "Open"` to confirm port 3306 is open internally.
7. **External RDS Isolation**: Run `nc -zv <rds-endpoint> 3306` from a local laptop. Confirm the connection fails/times out.
8. **EFS Shared Mount Verification**: Verify `/mnt/shared` is mounted on both app instances (`df -h | grep efs`) and confirm file writes persist across instances.
9. **S3 Gateway Endpoint Operation**: Verify `dnf update` or package queries succeed from private instances without a public NAT Gateway.
10. **Storage Encryption Audit**: Verify in the AWS Management Console that EBS, RDS, and EFS volumes all display `Encryption: Enabled`.

---

## 9. Cost notes
* **Application Load Balancer:** ~$0.60 per day.
* **VPC Interface Endpoints (3):** ~$0.65 per day.
* **Total Cost Incurred (from Cost Explorer):** $X.XX

## 10. How to destroy
1. Empty the `depi-sec-app` and `depi-sec-logs` S3 buckets completely (including all non-current versions).
2. Run `terraform destroy`.
*Note: The AWS Backup Vault has a governance lock. If a recovery point is within its 7-day minimum retention period, the vault may fail to destroy until the retention ends. Delete all other resources, keep the vault, and clean it up manually after the retention period.*

## 11. What I learned
Building this infrastructure end-to-end provided deep practical insight into multi-tier AWS network security and Infrastructure as Code best practices:
1. Understood how CloudFront custom secret header validation effectively prevents direct origin attacks on public load balancers.
2. Mastered the implementation of strict private subnet architectures where compute instances operate securely without public IP addresses.
3. Learned how to manage EC2 instances out-of-band using AWS Systems Manager Session Manager, eliminating the need for SSH keys and open port 22.
4. Gained practical experience troubleshooting `user_data` boot script failures by inspecting `/var/log/cloud-init-output.log`.
5. Learned the distinction between NAT Gateways and VPC Endpoints, utilizing S3 Gateway Endpoints for zero-cost internal repository access.
6. Understood the necessity of decoupling storage and compute layers using Amazon EFS for shared application state across Availability Zones.
7. Practiced setting up explicit security group chaining where backend services only accept traffic directly referenced from frontend security group IDs.
8. Experienced handling S3 bucket versioning and object lock restrictions during automated `terraform destroy` workflows.
9. Learned how to structure modular Terraform code to maintain clean separation between networking, security, compute, and database layers.
10. Developed structured verification testing workflows to systematically prove security boundaries from both internal and external vantage points.

---

## 12. Known limitations
* **Single-AZ Database**: The RDS instance is deployed in a Single-AZ configuration for cost efficiency; upgrading to Multi-AZ with read replicas would provide true database fault tolerance.
* **HTTP Origin Communication**: Traffic between the CloudFront edge and the ALB currently runs over HTTP (Port 80); implementing custom domain SSL certificates via AWS Certificate Manager (ACM) would enforce end-to-end HTTPS encryption.
* **Lack of WAF Protection**: Adding AWS WAF to CloudFront would provide layer 7 protection against common web exploits (SQLi, XSS) and rate-limiting against DDoS attacks.
* **Manual Target Group Scaling**: The architecture uses standalone EC2 instances; replacing them with an Auto Scaling Group (ASG) would enable automatic capacity scaling based on CPU or network load.
# Architecture Overview – Secure AWS Web Platform

## 1. Executive Summary
This architecture defines a multi-tier, highly available, and isolated web platform hosted on Amazon Web Services (AWS) in the `us-east-1` region. The infrastructure is designed according to the AWS Well-Architected Framework, emphasizing perimeter defense, zero-trust network access, storage encryption, and out-of-band instance administration.

The entry point utilizes **Amazon CloudFront** as an edge security boundary and content delivery network, which forwards authenticated traffic to a public **Application Load Balancer (ALB)** using origin header verification. The core application logic runs on Nginx web servers hosted on **Amazon EC2** instances residing strictly within private subnets, completely decoupled from direct internet exposure. State management and persistent storage are handled by **Amazon EFS** (shared filesystem) and **Amazon RDS for MySQL** (relational database).

---

## 2. Component Topology

```text
                         [ Internet Users ]
                                 │
                                 ▼
                     [ Amazon CloudFront ]
                     (HTTPS / Edge Cache)
                                 │
                        (Secret Header)
                                 │
                                 ▼
              [ Application Load Balancer (ALB) ]
                     (Public Subnets)
                                 │
                 ┌───────────────┴───────────────┐
                 ▼                               ▼
      [ EC2 App Server A ]              [ EC2 App Server B ]
         (Subnet Private A)                (Subnet Private B)
                 │                               │
                 ├───────────────┬───────────────┤
                 ▼               ▼               ▼
           [ Amazon EFS ]   [ RDS MySQL ]  [ Neptune Cluster ]
          (Shared Files)    (Private DB)     (Graph DB)
```

### Core AWS Services & Roles
* **Amazon CloudFront**: Acts as the global content delivery network (CDN) and primary edge shield, enforcing HTTPS termination and injecting custom origin headers.
* **AWS Application Load Balancer (`depi-sec-alb`)**: Spans public subnets across multiple Availability Zones to distribute incoming HTTP traffic based on rule-matching conditions.
* **Amazon EC2 (`depi-sec-app-a`, `depi-sec-app-b`)**: Compute nodes running Amazon Linux 2023 with Nginx installed, deployed across private subnets without public IP addresses.
* **Amazon EFS (`shared_fs`)**: POSIX-compliant network file system mounted at `/mnt/shared` via TLS for cross-AZ state sharing.
* **Amazon RDS MySQL (`depi-sec-rds-mysql`)**: Isolated database cluster configured in a private DB subnet group listening on port 3306.
* **Amazon Neptune (`depi-sec-neptune-cluster`)**: Private graph database cluster for specialized query relationship mapping.
* **AWS Systems Manager (Session Manager)**: Provides shell-level management capabilities over HTTPS without open inbound ports or SSH keys.
* **VPC Gateway Endpoint (S3)**: Routes internal package updates (`yum`/`dnf`) directly to Amazon S3 repositories without exposing instances to public NAT or internet routes.

---

## 3. Network Architecture & Subnet Planning

The platform resides inside `depi-sec-app-vpc` (`10.0.0.0/16`) spanning two Availability Zones (`us-east-1a` and `us-east-1b`).

### Subnet Layout

| Subnet Identifier | CIDR Block | Availability Zone | Route Table Target | Purpose / Hosted Resources |
| :--- | :--- | :--- | :--- | :--- |
| **`public_a`** | `10.0.1.0/24` | `us-east-1a` | Internet Gateway (`igw`) | ALB Ingress Node A |
| **`public_b`** | `10.0.2.0/24` | `us-east-1b` | Internet Gateway (`igw`) | ALB Ingress Node B |
| **`private_a`** | `10.0.10.0/24` | `us-east-1a` | S3 Gateway Endpoint | EC2 App Server A, EFS Mount Target A, RDS Node A |
| **`private_b`** | `10.0.20.0/24` | `us-east-1b` | S3 Gateway Endpoint | EC2 App Server B, EFS Mount Target B, RDS Node B |

### Routing Table Configuration
1. **Public Route Table (`public_rt`)**:
   * `10.0.0.0/16` ➔ `local`
   * `0.0.0.0/0` ➔ `Internet Gateway`
2. **Private Route Table (`private_rt`)**:
   * `10.0.0.0/16` ➔ `local`
   * `pl-xxxxx (S3 Prefix List)` ➔ `vpce-s3-gateway`

---

## 4. Security Architecture & Boundary Controls

```text
[ Attacker ] ──( Direct ALB Request )──► [ ALB ] ──( Header Check Fail )──► 403 Forbidden
[ Attacker ] ──( Direct EC2 Request )──► [ Network Boundary ] ───────────► NO ROUTE / DROP
```

### Defense-in-Depth Layering
1. **Origin Defense (Header Verification)**:
   * CloudFront appends a custom header (e.g., `X-Origin-Verify`) to all origin requests.
   * The ALB listener rule evaluates every request: matching headers are forwarded to the target group; unauthenticated requests receive an immediate `403 Forbidden`.

2. **Network Isolation**:
   * Compute and database resources have `associate_public_ip_address = false`.
   * Security groups (`app_sg`, `db_sg`, `efs_sg`) use explicit rule chaining (referencing source Security Group IDs rather than CIDR ranges).

3. **Database Guardrails**:
   * The RDS MySQL instance explicitly sets `publicly_accessible = false`.
   * Inbound database rules (`depi-sec-db-sg`) allow TCP port 3306 **only** from instances carrying `aws_security_group.app_sg.id`.

4. **Zero-Trust Administrative Management**:
   * Port 22 (SSH) is completely disabled in all Security Groups.
   * IAM policy attachments permit the SSM Agent to communicate with `ssm.us-east-1.amazonaws.com` over outbound HTTPS (443).

---

## 5. Storage & Data Protection

| Storage Layer | Service | Encryption Standard | Redundancy & Access Control |
| :--- | :--- | :--- | :--- |
| **Root Disk** | Amazon EBS (`gp3`) | AWS KMS (`aws/ebs`) | Encrypted at rest; snapshots managed via AWS Backup. |
| **Shared File System** | Amazon EFS | AWS KMS (`aws/elasticfilesystem`) | Multi-AZ mount targets mounted using `amazon-efs-utils` with forced TLS (`-o tls`). |
| **Relational DB** | Amazon RDS MySQL | AWS KMS (`aws/rds`) | Storage encrypted (`storage_encrypted = true`); credentials managed in AWS Secrets Manager. |
| **Graph DB** | Amazon Neptune | AWS KMS (`aws/neptune`) | Cluster storage encrypted at rest across private DB subnets. |

---

## 6. Traffic Flow Matrix

```text
Client Browser
   │ (HTTPS:443)
   ▼
Amazon CloudFront Edge
   │ (Injects custom header: X-Origin-Verify)
   ▼
Application Load Balancer (Public Subnets)
   │ (Validates header -> Routes via Port 80)
   ▼
EC2 App Servers (Private Subnets)
   ├─► Reads/Writes Shared Data ──► Amazon EFS (Port 2049, TLS)
   ├─► Queries Data ─────────────► Amazon RDS MySQL (Port 3306)
   └─► System / Package Updates ──► S3 Gateway Endpoint (Internal AWS Backbone)
```
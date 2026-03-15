# Terraform Remote State Backend Guide

> **Learning Note**: This project uses **local state** for simplicity. This document explains remote state concepts for future reference when working with teams or production environments.

---

## What is Terraform State?

Terraform state is a snapshot of your infrastructure. It tracks:
- Resources created by Terraform
- Metadata and relationships between resources
- Sensitive data (sometimes)

```
terraform.tfstate  ← Local state file (gitignored)
```

---

## Local State vs Remote State

| Aspect | Local State | Remote State |
|--------|--------------|--------------|
| **Location** | `terraform.tfstate` on your machine | S3 bucket (or other backend) |
| **Team Use** | ❌ Cannot share | ✅ Team can collaborate |
| **Locking** | ❌ No locking (conflicts possible) | ✅ DynamoDB prevents concurrent changes |
| **Security** | ⚠️ State file on local disk | ✅ Encrypted in S3 |
| **Disaster Recovery** | ❌ Lost if disk fails | ✅ Versioned in S3 |
| **Best For** | Learning, personal projects | Teams, production |

---

## Why Use Remote State?

### 1. **Team Collaboration**
Multiple developers can work on the same infrastructure:
```
Developer A runs terraform apply → State locked
Developer B tries to apply → Waits for lock
Developer A finishes → Lock released
Developer B can now apply
```

### 2. **State Locking**
Prevents corruption from concurrent operations:
```
Without Locking:
  Dev A applies → Modifies state
  Dev B applies → Overwrites Dev A's changes
  Result: CORRUPTED STATE

With Locking (DynamoDB):
  Dev A acquires lock → Applies
  Dev B waits → Dev A releases lock
  Dev B acquires lock → Applies
  Result: SAFE
```

### 3. **Security**
- State files contain sensitive data (passwords, keys)
- S3 can encrypt at rest
- IAM policies control who can read/write

### 4. **Versioning & Recovery**
- S3 versioning keeps history of all state changes
- Can rollback to previous state if something breaks

---

## Remote State Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Your Computer                            │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  Terraform Configuration                             │    │
│  │  - main.tf                                           │    │
│  │  - variables.tf                                      │    │
│  │  - versions.tf (backend config)                     │    │
│  └─────────────────────────────────────────────────────┘    │
│                           │                                  │
│                           │ terraform apply                  │
│                           ▼                                  │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ HTTPS
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                          AWS Cloud                           │
│  ┌─────────────────┐    ┌─────────────────────────────┐    │
│  │   DynamoDB      │◄──►│        S3 Bucket            │    │
│  │  (State Lock)   │    │  eks/terraform.tfstate     │    │
│  │                 │    │  - Version 1 (current)      │    │
│  │  eks-terraform- │    │  - Version 2                │    │
│  │  locks          │    │  - Version 3                │    │
│  └─────────────────┘    │  - Encrypted (KMS)          │    │
│                         └─────────────────────────────┘    │
│                                                          │
│  ┌─────────────────────────────────────────────────────┐ │
│  │              EKS + VPC Resources                    │ │
│  │  - EKS Cluster                                       │ │
│  │  - VPC, Subnets                                     │ │
│  │  - IAM Roles                                        │ │
│  │  - EC2 Instances                                    │ │
│  └─────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

---

## Files Required for Remote State

### 1. `versions.tf` - Backend Configuration

```hcl
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote state backend
  backend "s3" {
    bucket         = "eks-terraform-state-ap-south-1"
    key            = "eks/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "eks-terraform-locks"
    encrypt        = true
  }
}
```

| Field | Purpose |
|-------|---------|
| `bucket` | S3 bucket name for state file |
| `key` | Path inside bucket (can store multiple states) |
| `region` | AWS region for S3 bucket |
| `dynamodb_table` | Table for state locking |
| `encrypt` | Enable S3 server-side encryption |

### 2. `bootstrap-state-storage.tf` - Creates S3 + DynamoDB

```hcl
# This creates the backend infrastructure BEFORE enabling remote state
module "state_storage" {
  source = "./modules/state-storage"

  bucket_name    = "eks-terraform-state-ap-south-1"
  dynamodb_table  = "eks-terraform-locks"
  region         = "ap-south-1"
}
```

**Why bootstrap?** Terraform cannot create the S3 bucket if its state needs to be stored in that same bucket. It's a chicken-and-egg problem.

### 3. `modules/state-storage/main.tf` - Infrastructure Definition

```hcl
# S3 Bucket for State Storage
resource "aws_s3_bucket" "terraform_state" {
  bucket = var.bucket_name

  lifecycle {
    prevent_destroy = true  # Prevent accidental deletion
  }
}

# Enable Versioning
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Enable Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

# Block Public Access
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB Table for State Locking
resource "aws_dynamodb_table" "terraform_locks" {
  name         = var.dynamodb_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
```

| Resource | Purpose |
|----------|---------|
| `aws_s3_bucket` | Stores state file |
| `aws_s3_bucket_versioning` | Keeps history of changes |
| `aws_s3_bucket_server_side_encryption_configuration` | Encrypts state at rest |
| `aws_s3_bucket_public_access_block` | Security best practice |
| `aws_dynamodb_table` | Locks state during operations |

### 4. `modules/state-storage/variables.tf` - Input Variables

```hcl
variable "bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  type        = string
}

variable "dynamodb_table" {
  description = "Name of the DynamoDB table for state locking"
  type        = string
  default     = "terraform-locks"
}

variable "region" {
  description = "AWS region for the bucket"
  type        = string
}
```

### 5. `modules/state-storage/outputs.tf` - Output Values

```hcl
output "bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.terraform_state.arn
}

output "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table"
  value       = aws_dynamodb_table.terraform_locks.arn
}
```

---

## Bootstrap Sequence (Step-by-Step)

### Why Bootstrap?

```
┌────────────────────────────────────────────────────────────┐
│  The Chicken-and-Egg Problem                               │
│                                                            │
│  Terraform needs S3 bucket to store state                   │
│  But creating S3 bucket produces state                     │
│  Where do we store that state?                             │
│                                                            │
│  Solution:                                                  │
│  1. First apply with LOCAL state (creates bucket)          │
│  2. Then migrate to REMOTE state                           │
└────────────────────────────────────────────────────────────┘
```

### Step 1: Initialize with Local State

```bash
terraform init
```
- Downloads providers and modules
- State will be local (`terraform.tfstate`)

### Step 2: Create S3 Bucket and DynamoDB Table

```bash
terraform apply -target=module.state_storage
```
- `-target` flag applies only the state storage resources
- Creates S3 bucket + DynamoDB table
- State is still local at this point

### Step 3: Enable Remote Backend

Edit `versions.tf` - uncomment the backend block:

```hcl
terraform {
  # ... providers ...

  backend "s3" {
    bucket         = "eks-terraform-state-ap-south-1"
    key            = "eks/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "eks-terraform-locks"
    encrypt        = true
  }
}
```

### Step 4: Migrate State to Remote

```bash
terraform init -migrate-state
```
- Copies local state to S3
- Enables DynamoDB locking
- Local state becomes backup

### Step 5: Continue Normal Operations

```bash
terraform apply  # Now uses remote state
terraform destroy  # Also uses remote state
```

---

## S3 Bucket Naming Requirements

```
✅ Valid: eks-terraform-state-ap-south-1
✅ Valid: my-terraform-state-123
❌ Invalid: TerraformState (uppercase)
❌ Invalid: eks.terraform.state (dots)
❌ Invalid: eks_terraform_state (underscores)
❌ Invalid: eks-terraform-state (too short, must be 3+ chars)

Rules:
- 3-63 characters
- Lowercase letters, numbers, hyphens only
- Must start with letter or number
- Must be globally unique (across all AWS accounts)
```

---

## Common Issues

### Issue 1: Bucket Already Exists

```
Error: Error creating S3 bucket: BucketAlreadyExists
```

**Solution**: S3 bucket names are globally unique. Choose a different name:

```hcl
bucket = "my-unique-terraform-state-12345"
```

### Issue 2: DynamoDB Table Already Exists

```
Error: Resource "aws_dynamodb_table" exists
```

**Solution**: Use a unique table name or import existing:

```bash
terraform import aws_dynamodb_table.terraform_locks eks-terraform-locks
```

### Issue 3: State Lock Error

```
Error: Error acquiring the state lock
```

**Solution**: Another operation is running. Wait or force-unlock:

```bash
terraform force-unlock <LOCK_ID>
```

### Issue 4: Permission Denied

```
Error: AccessDenied: User is not authorized
```

**Solution**: Ensure IAM permissions:

```json
{
  "Effect": "Allow",
  "Action": [
    "s3:PutObject",
    "s3:GetObject",
    "s3:DeleteObject",
    "s3:ListBucket"
  ],
  "Resource": [
    "arn:aws:s3:::eks-terraform-state-ap-south-1",
    "arn:aws:s3:::eks-terraform-state-ap-south-1/*"
  ]
}
```

---

## Cost of Remote State

| Resource | Monthly Cost |
|----------|---------------|
| S3 Bucket | ~$0.023/GB |
| S3 Requests | ~$0.0004 per 1,000 requests |
| DynamoDB (PAY_PER_REQUEST) | Free tier covers most Terraform usage |
| **Total for typical use** | **< $1/month** |

---

## Best Practices

1. **Use unique bucket names** - Include account ID or region
2. **Enable versioning** - Always enable S3 versioning
3. **Enable encryption** - Use KMS encryption
4. **Block public access** - Always block public access
5. **Use lifecycle prevent_destroy** - Prevent accidental bucket deletion
6. **Separate state per environment** - Use different keys or buckets for dev/staging/prod

---

## When to Use Remote State

| Scenario | Recommendation |
|----------|----------------|
| Learning/Personal | Local state is fine |
| Team of 1-2 | Local state or simple remote |
| Team of 3+ | Remote state required |
| Production | Remote state required |
| Multiple environments | Remote state required |

---

## Summary

```
Local State (This Project):
┌─────────────────────────────────┐
│  terraform.tfstate (local file) │
│  - Simple                        │
│  - Good for learning             │
│  - No additional AWS resources   │
└─────────────────────────────────┘

Remote State (Teams/Production):
┌─────────────────────────────────┐
│  S3 Bucket + DynamoDB            │
│  - Team collaboration            │
│  - State locking                 │
│  - Version history               │
│  - Encrypted at rest             │
└─────────────────────────────────┘
```

---

## Files Reference

| File | Purpose | Required for Remote State |
|------|---------|---------------------------|
| `versions.tf` | Backend configuration | Yes (uncomment backend block) |
| `bootstrap-state-storage.tf` | Creates S3 + DynamoDB | Yes (run once) |
| `modules/state-storage/main.tf` | State infrastructure resources | Yes |
| `modules/state-storage/variables.tf` | Input variables | Yes |
| `modules/state-storage/outputs.tf` | Output values | Yes |
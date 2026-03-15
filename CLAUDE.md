# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Terraform project that provisions a complete Amazon EKS cluster on AWS. Uses official Terraform AWS modules for VPC and EKS.

## Architecture

```
terraform-eks/
├── versions.tf          # Terraform/provider versions + remote state backend (commented)
├── provider.tf          # AWS provider config + data sources (account ID, AZs)
├── variables.tf         # All input variables
├── main.tf              # VPC module + EKS module configuration
├── outputs.tf           # Cluster endpoint, VPC ID, subnet IDs
├── bootstrap-state-storage.tf  # Creates S3 bucket + DynamoDB for remote state
└── modules/state-storage/      # Module for state infrastructure
```

**Dependency Flow**: VPC module outputs (vpc_id, private_subnets, public_subnets) → EKS module inputs

**Key Modules**:
- `terraform-aws-modules/vpc/aws` ~> 5.0
- `terraform-aws-modules/eks/aws` ~> 20.0

## Commands

```bash
# Initialize (first time - uses local state)
terraform init

# Bootstrap remote state infrastructure (first time only)
terraform apply -target=module.state_storage

# Migrate to remote state after bootstrap (uncomment backend in versions.tf first)
terraform init -migrate-state

# Plan/apply
terraform plan
terraform apply

# Destroy cluster
terraform destroy

# Connect to cluster
aws eks update-kubeconfig --region <region> --name <cluster-name>
kubectl get nodes
```

## Configuration

- Default region: `ap-south-1`
- Default Kubernetes version: `1.31`
- Node group: `t3.medium`, min 1 / max 3 / desired 2
- VPC CIDR: `10.20.0.0/16` with 3 AZs

Copy `terraform.tfvars.example` to `terraform.tfvars` and customize.

## Remote State Backend

S3 bucket (`eks-terraform-state-ap-south-1`) + DynamoDB table (`eks-terraform-locks`).
- Versioning and KMS encryption enabled
- Public access blocked
- PAY_PER_REQUEST billing (free tier compatible)
- `prevent_destroy` lifecycle on state bucket

**Bootstrap sequence**:
1. `terraform init` (local state)
2. `terraform apply -target=module.state_storage`
3. Uncomment backend block in `versions.tf`
4. `terraform init -migrate-state`

## Important Files

| File | Purpose |
|------|---------|
| `*.json` | IAM trust policies for EKS access patterns (bastion, user assume role) |
| `modules/state-storage/` | Creates S3 bucket and DynamoDB table for remote state |

## Notes

- Single NAT gateway (cost-optimized, not HA)
- Cluster creator gets admin permissions by default
- IRSA enabled for service account IAM roles
- `kubectl` binary should NOT be in repo (use system-wide install)
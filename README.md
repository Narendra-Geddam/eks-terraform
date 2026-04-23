<div align="center">

# 🚀 EKS on AWS with Terraform

### Production-Ready Kubernetes Infrastructure as Code

[![Terraform](https://img.shields.io/badge/Terraform-1.6%2B-7B42BC?style=for-the-badge&logo=terraform)](https://www.terraform.io/)
[![AWS Provider](https://img.shields.io/badge/AWS-Provider-5.0%2B-FF9900?style=for-the-badge&logo=amazon-aws)](https://registry.terraform.io/providers/hashicorp/aws/)
[![EKS Version](https://img.shields.io/badge/EKS-1.31-326CE5?style=for-the-badge&logo=kubernetes)](https://aws.amazon.com/eks/)
[![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](LICENSE)

<img src="https://img.shields.io/github/stars/yourusername/terraform-eks?style=for-the-badge&logo=github" alt="GitHub Stars"/>
<img src="https://img.shields.io/github/last-commit/yourusername/terraform-eks?style=for-the-badge&logo=git" alt="Last Commit"/>
<img src="https://img.shields.io/github/issues/yourusername/terraform-eks?style=for-the-badge" alt="Issues"/>

</div>

---

## 📋 Overview

<table>
<tr>
<td width="50%">

This repository provisions a **complete Amazon EKS cluster** using Terraform:

- ✅ **VPC** across 3 Availability Zones
- ✅ **Public & Private Subnets** with NAT Gateway
- ✅ **EKS Control Plane** (AWS Managed)
- ✅ **Managed Node Groups** (Auto-scaling)
- ✅ **EKS Add-ons** (VPC-CNI, CoreDNS, kube-proxy)
- ✅ **Cluster Autoscaler** (IRSA enabled)
- ✅ **Cost Management** scripts included

</td>
<td width="50%" align="center">

<img src="https://img.shields.io/badge/Infrastructure-100%25-2EA44F?style=for-the-badge" alt="Infrastructure"/>
<img src="https://img.shields.io/badge/IaC-Terraform-7B42BC?style=for-the-badge&logo=terraform" alt="Terraform"/>

<br/><br/>

```
Cost: ~$11-27/month
(4-6 hrs/day, 3-5 days/week)
```

</td>
</tr>
</table>

---

## 🏗️ Architecture

<div align="center">

```
┌──────────────────────────────────────────────────────────────────┐
│                        AWS Cloud                                 │
│  ┌───────────────────────────────────────────────────────────┐   │
│  │                    VPC (10.20.0.0/16)                     │   │
│  │                                                           │   │
│  │   ┌─────────┐  ┌─────────┐  ┌─────────┐                   │   │
│  │   │  AZ-1   │  │  AZ-2   │  │  AZ-3   │  3 Availability   │   │
│  │   │ Public  │  │ Public  │  │ Public  │    Zones          │   │
│  │   │ Private │  │ Private │  │ Private │                   │   │
│  │   │ [Node]  │  │ [Node]  │  │ [Node]  │                   │   │
│  │   └────┬────┘  └────┬────┘  └────┬────┘                   │   │
│  │        └────────────┼───────────┘                         │   │
│  │                     │                                     │   │
│  │            ┌────────▼────────┐                            │   │
│  │            │   NAT Gateway   │                            │   │
│  │            └────────┬────────┘                            │   │
│  └─────────────────────┼─────────────────────────────────────┘   │
│                        │                                         │
│  ┌─────────────────────▼──────────────────────────────────────┐  │
│  │              EKS Control Plane                             │  │
│  │   ┌─────────┐ ┌─────────┐ ┌──────────┐ ┌─────────────┐     │  │
│  │   │ API     │ │ etcd    │ │Scheduler │ │ Controller  │     │  │
│  │   │ Server  │ │ (3 repl)│ │          │ │ Manager     │     │  │
│  │   └─────────┘ └─────────┘ └──────────┘ └─────────────┘     │  │
│  │                                                            │  │
│  │   Add-ons: VPC-CNI | CoreDNS | kube-proxy                  │  │
│  └────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
```

</div>

---

## 📁 Project Structure

<table>
<tr>
<th>File</th>
<th>Purpose</th>
<th>Status</th>
</tr>
<tr>
<td><code>infra/environments/prod/main.tf</code></td>
<td>VPC + EKS + Add-ons configuration</td>
<td>✅ Active</td>
</tr>
<tr>
<td><code>infra/environments/prod/variables.tf</code></td>
<td>Input variables</td>
<td>✅ Active</td>
</tr>
<tr>
<td><code>infra/environments/prod/outputs.tf</code></td>
<td>Cluster outputs (endpoint, VPC ID)</td>
<td>✅ Active</td>
</tr>
<tr>
<td><code>infra/environments/prod/cluster-autoscaler.tf</code></td>
<td>IRSA role for Cluster Autoscaler</td>
<td>✅ Active</td>
</tr>
<tr>
<td><code>infra/environments/prod/versions.tf</code></td>
<td>Terraform & provider versions</td>
<td>✅ Active</td>
</tr>
<tr>
<td><code>scripts/start-cluster.ps1</code></td>
<td>Quick start script</td>
<td>✅ Active</td>
</tr>
<tr>
<td><code>scripts/stop-cluster.ps1</code></td>
<td>Quick destroy script</td>
<td>✅ Active</td>
</tr>
<tr>
<td><code>docs/guides/backend.md</code></td>
<td>Remote state learning guide</td>
<td>📖 Documentation</td>
</tr>
<tr>
<td><code>docs/guides/eks.md</code></td>
<td>Complete EKS guide + Interview prep</td>
<td>📖 Documentation</td>
</tr>
</table>

<details>
<summary>📚 Reference Files (for learning)</summary>

| File | Purpose |
|------|---------|
| `infra/environments/prod/bootstrap-state-storage.tf` | S3 + DynamoDB for remote state |
| `infra/modules/state-storage/` | State infrastructure module |

</details>

---

## ⚡ Quick Start

<details open>
<summary><b>🚀 Deploy EKS Cluster</b></summary>

### Prerequisites

- Terraform `>= 1.6.0`
- AWS CLI configured with credentials
- kubectl (optional, for cluster interaction)

### Step 1: Initialize & Deploy

```powershell
# Clone the repository
git clone <your-repo-url>
cd terraform-eks
cd infra/environments/prod

# Copy example variables
Copy-Item terraform.tfvars.example terraform.tfvars

# Edit variables (optional)
# Notepad terraform.tfvars

# Initialize Terraform
terraform init

# Plan infrastructure
terraform plan

# Deploy (takes 15-25 minutes)
terraform apply
```

### Step 2: Connect to Cluster

```powershell
# Update kubeconfig
aws eks update-kubeconfig --region ap-south-1 --name my-eks-cluster

# Verify connection
kubectl get nodes
```

### Step 3: Deploy Cluster Autoscaler

```powershell
# Apply autoscaler manifest
terraform output -raw cluster_autoscaler_manifest | kubectl apply -f -

# Verify autoscaler is running
kubectl get pods -n kube-system -l app=cluster-autoscaler
```

</details>

<details>
<summary><b>🛑 Stop & Destroy (Save Costs)</b></summary>

```powershell
# Use the provided script
..\..\..\scripts\stop-cluster.ps1

# Or manually
terraform destroy
```

**Cost savings**: Destroy when not in use to save ~$170/month (pay only during active hours)

</details>

---

## 💰 Cost Management

<div align="center">

| Usage Pattern | Monthly Cost | Savings |
|---------------|--------------|---------|
| 24/7 Running | ~$170/month | Baseline |
| 4 hrs × 3 days/week | ~$11/month | **94%** |
| 6 hrs × 5 days/week | ~$27/month | **84%** |

</div>

<details>
<summary>📊 Cost Breakdown</summary>

| Resource | Hourly Cost | Monthly (24/7) |
|----------|-------------|----------------|
| EKS Control Plane | $0.10/hr | $73 |
| NAT Gateway | $0.045/hr | $33 |
| 2× t3.medium nodes | $0.084/hr | $61 |
| EBS Volumes | - | $6 |
| **Total** | - | **~$173** |

</details>

<details>
<summary>💡 Cost Optimization Tips</summary>

1. **Destroy after use** - Use `scripts/stop-cluster.ps1` when done
2. **Use Spot instances** - 70-90% cheaper (for fault-tolerant workloads)
3. **Scale to zero** - Set `min_size = 0` in dev environments
4. **Right-size nodes** - Monitor usage with `kubectl top nodes`

</details>

---

## 📖 Documentation

<div align="center">

| Document | Description |
|----------|-------------|
| [**docs/guides/eks.md**](docs/guides/eks.md) | Complete EKS guide - architecture, components, interview scenarios |
| [**docs/guides/backend.md**](docs/guides/backend.md) | Remote state concepts - S3 + DynamoDB backend |

</div>

---

## 🔧 Configuration

<details>
<summary><b>⚙️ Customizable Variables</b></summary>

| Variable | Default | Description |
|----------|---------|-------------|
| `aws_region` | `ap-south-1` | AWS deployment region |
| `cluster_name` | `my-eks-cluster` | EKS cluster name |
| `kubernetes_version` | `1.31` | Kubernetes version |
| `vpc_cidr` | `10.20.0.0/16` | VPC CIDR block |
| `node_instance_types` | `["t3.medium"]` | EC2 instance types |
| `node_desired_size` | `2` | Desired node count |
| `node_min_size` | `1` | Minimum nodes |
| `node_max_size` | `3` | Maximum nodes |
| `cluster_endpoint_public_access_cidrs` | `["0.0.0.0/0"]` | Allowed CIDRs for API access |

Edit `infra/environments/prod/terraform.tfvars` to customize:

```hcl
# terraform.tfvars
aws_region         = "us-east-1"
cluster_name       = "production-eks"
kubernetes_version = "1.31"
node_instance_types = ["m5.large"]
node_desired_size   = 3
node_min_size       = 2
node_max_size       = 10
cluster_endpoint_public_access_cidrs = ["203.0.113.0/24"]  # Office IP
```

</details>

---

## �️ Remote State Backend

By default, this project uses **local state** for simplicity. For team collaboration and production environments, you can enable remote state management with **S3 + DynamoDB**.

<details>
<summary><b>📚 Why Remote State?</b></summary>

| Benefit | Description |
|---------|-------------|
| **Team Collaboration** | Multiple developers can safely work on the same infrastructure with state locking |
| **State Locking** | DynamoDB prevents concurrent operations from corrupting state |
| **Security** | S3 encryption at rest protects sensitive data (passwords, keys) |
| **Versioning** | S3 versioning keeps history of all state changes for recovery |
| **Centralized** | No need to share state files via email or version control |

</details>

<details>
<summary><b>⚙️ Enable Remote State (Bootstrap)</b></summary>

### Step 1: Initialize with Local State
```bash
terraform init
```

### Step 2: Create S3 Bucket and DynamoDB Table
```bash
terraform apply -target=module.state_storage
```

### Step 3: Uncomment Backend in `versions.tf`

Edit `versions.tf` and uncomment the backend block:
```hcl
terraform {
  backend "s3" {
    bucket         = "eks-terraform-state-ap-south-1"
    key            = "eks/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "eks-terraform-locks"
    encrypt        = true
  }
}
```

### Step 4: Migrate State
```bash
terraform init -migrate-state
# Choose 'yes' when prompted to copy state
```

### Architecture
```
Your Computer              AWS Cloud
    │                    ┌─────────────────┐
    │ terraform apply    │   DynamoDB      │
    ├──────────────────► │  (State Lock)   │
    │                    └────────┬────────┘
    │                             │
    │                    ┌────────▼────────┐
    │                    │  S3 Bucket      │
    │                    │ (State File)    │
    │                    │ - Versioning    │
    │                    │ - Encryption    │
    │                    │ - Backups       │
    │                    └─────────────────┘
```

### Backend Configuration

| File | Purpose |
|------|---------|
| `versions.tf` | Backend configuration (comment/uncomment to toggle) |
| `bootstrap-state-storage.tf` | Defines S3 + DynamoDB resources |
| `modules/state-storage/` | Reusable module for state infrastructure |

**Cost**: ~$2/month (pay-per-request billing)

</details>

<details>
<summary><b>📖 Full Remote State Guide</b></summary>

See [**docs/guides/backend.md**](docs/guides/backend.md) for comprehensive documentation on:
- Terraform state concepts
- Local vs remote state comparison
- Bootstrap sequence
- Troubleshooting state issues
- Migration from local to remote state

</details>

---

## �🛡️ Security Best Practices

<div align="center">

| Practice | Status | Notes |
|----------|--------|-------|
| Private Subnets | ✅ | Worker nodes in private subnets |
| IRSA | ✅ | Pod-level IAM permissions |
| EKS Add-ons | ✅ | AWS managed security patches |
| API CIDR Restriction | ⚙️ | Configure in `terraform.tfvars` |
| Security Groups | ✅ | Managed by EKS module |

</div>

<details>
<summary>🔒 Security Configuration</summary>

```hcl
# Restrict API endpoint access (recommended for production)
cluster_endpoint_public_access_cidrs = [
  "203.0.113.0/24",    # Office IP range
  "198.51.100.0/24",   # VPN IP range
]

# Or use private-only access (most secure)
# cluster_endpoint_public_access = false
# cluster_endpoint_private_access = true
```

</details>

---

## 🎯 Features Implemented

<div align="center">

<img src="https://img.shields.io/badge/✅-VPC%203%20AZs-blue?style=flat-square" alt="VPC"/>
<img src="https://img.shields.io/badge/✅-Public%2FPrivate%20Subnets-blue?style=flat-square" alt="Subnets"/>
<img src="https://img.shields.io/badge/✅-NAT%20Gateway-blue?style=flat-square" alt="NAT"/>
<img src="https://img.shields.io/badge/✅-EKS%20Control%20Plane-blue?style=flat-square" alt="EKS"/>
<img src="https://img.shields.io/badge/✅-Managed%20Node%20Groups-blue?style=flat-square" alt="Nodes"/>

<br/>

<img src="https://img.shields.io/badge/✅-EKS%20Add%2Dons-green?style=flat-square" alt="Add-ons"/>
<img src="https://img.shields.io/badge/✅-Cluster%20Autoscaler-green?style=flat-square" alt="Autoscaler"/>
<img src="https://img.shields.io/badge/✅-IRSA-green?style=flat-square" alt="IRSA"/>
<img src="https://img.shields.io/badge/✅-Cost%20Scripts-green?style=flat-square" alt="Cost"/>

<br/>

<img src="https://img.shields.io/badge/📖-Remote%20State%20Guide-yellow?style=flat-square" alt="Backend"/>
<img src="https://img.shields.io/badge/📖-Interview%20Scenarios-yellow?style=flat-square" alt="Interview"/>
<img src="https://img.shields.io/badge/📖-Architecture%20Diagrams-yellow?style=flat-square" alt="Architecture"/>

</div>

---

## 🚀 Roadmap

<div align="center">

| Feature | Status | Priority |
|---------|--------|----------|
| AWS Load Balancer Controller | 📋 Planned | High |
| Metrics Server | 📋 Planned | High |
| ExternalDNS | 📋 Planned | Medium |
| VPC Flow Logs | 📋 Planned | Medium |
| CloudWatch Container Insights | 📋 Planned | Low |

</div>

---

## 📝 Recent Changes

<details>
<summary>Changelog</summary>

### 2024-03
- ✅ Added remote state backend (S3 + DynamoDB)
- ✅ Added EKS managed add-ons (coredns, kube-proxy, vpc-cni)
- ✅ Added Cluster Autoscaler IRSA role
- ✅ Added API endpoint CIDR restrictions variable
- ✅ Added start/stop scripts for cost management
- ✅ Added comprehensive `docs/guides/eks.md` documentation
- ✅ Added `docs/guides/backend.md` for learning
- ✅ Removed kubectl binary from repository

</details>

---

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

<div align="center">

**Made with ❤️ for learning Kubernetes on AWS**

<img src="https://img.shields.io/badge/⭐-If%20this%20helped%20you-blue?style=for-the-badge" alt="Star"/>

[**📚 Read the Full EKS Guide**](docs/guides/eks.md) | [**📚 Remote State Guide**](docs/guides/backend.md)

</div>
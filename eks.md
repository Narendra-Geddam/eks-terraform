<div align="center">

# 🐙 Amazon EKS - Complete Implementation Guide

### From Beginner to Production-Ready

[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.31-326CE5?style=for-the-badge&logo=kubernetes)](https://kubernetes.io/)
[![AWS EKS](https://img.shields.io/badge/AWS-EKS-FF9900?style=for-the-badge&logo=amazon-aws)](https://aws.amazon.com/eks/)
[![Terraform](https://img.shields.io/badge/Terraform-IaC-7B42BC?style=for-the-badge&logo=terraform)](https://www.terraform.io/)
[![Difficulty](https://img.shields.io/badge/Difficulty-Intermediate-yellow?style=for-the-badge)](https://github.com)

<img src="https://img.shields.io/badge/Architecture-✅-2EA44F?style=flat-square" alt="Architecture"/>
<img src="https://img.shields.io/badge/Networking-✅-2EA44F?style=flat-square" alt="Networking"/>
<img src="https://img.shields.io/badge/Security-✅-2EA44F?style=flat-square" alt="Security"/>
<img src="https://img.shields.io/badge/Interview%20Prep-✅-2EA44F?style=flat-square" alt="Interview"/>

</div>

---

> 📖 A comprehensive guide covering all EKS components, architecture, best practices, and real-world scenarios. Perfect for interview preparation and production implementations.

---

## 📑 Table of Contents

<div align="center">

| Section | Topic | Level |
|---------|-------|-------|
| 1 | [Overview](#1-overview) | 🟢 Beginner |
| 2 | [Architecture Deep Dive](#2-architecture-deep-dive) | 🟡 Intermediate |
| 3 | [Networking Layer](#3-networking-layer) | 🟡 Intermediate |
| 4 | [EKS Control Plane](#4-eks-control-plane) | 🟡 Intermediate |
| 5 | [Worker Nodes](#5-worker-nodes) | 🟡 Intermediate |
| 6 | [EKS Add-ons](#6-eks-add-ons) | 🟡 Intermediate |
| 7 | [Cluster Autoscaler](#7-cluster-autoscaler) | 🔴 Advanced |
| 8 | [IRSA](#8-iam-roles-for-service-accounts-irsa) | 🔴 Advanced |
| 9 | [Security Best Practices](#9-security-best-practices) | 🔴 Advanced |
| 10 | [Cost Optimization](#10-cost-optimization) | 🟡 Intermediate |
| 11 | [Interview Scenarios](#11-interview-scenarios) | 🔴 Advanced |
| 12 | [Troubleshooting Guide](#12-troubleshooting-guide) | 🔴 Advanced |

</div>

---

## 🚀 Quick Links

<div align="center">

[**🏛️ Architecture**](#2-architecture-deep-dive) · [**🔧 Components**](#6-eks-add-ons) · [**💰 Cost**](#10-cost-optimization) · [**🎯 Interview**](#11-interview-scenarios) · [**🛠️ Troubleshoot**](#12-troubleshooting-guide)

</div>

---

## 1. Overview <a name="1-overview"></a>

| Aspect | EKS | Self-Managed (kubeadm, kops) |
|--------|-----|------------------------------|
| Control Plane | AWS manages | You manage |
| High Availability | Built-in (3 AZs) | You configure |
| Upgrades | One-click upgrade | Manual process |
| etcd Backup | Automatic | You manage |
| API Server | Auto-scaling | You scale |
| Security Patches | Automatic | Manual |
| Cost | $0.10/hour + nodes | Only nodes |

### Key Benefits

```
┌─────────────────────────────────────────────────────────────────┐
│                      Why EKS?                                   │
├─────────────────────────────────────────────────────────────────┤
│  ✅ Managed Control Plane - AWS handles etcd, API server       │
│  ✅ Automatic Upgrades - Security patches applied automatically │
│  ✅ High Availability - Runs across 3 AZs by default           │
│  ✅ AWS Integration - IAM, VPC, CloudWatch, ALB               │
│  ✅ Latest Kubernetes - Supports versions within 14 months      │
│  ✅ EKS Add-ons - Managed components (coredns, vpc-cni, etc.)   │
└─────────────────────────────────────────────────────────────────┘
```

### This Project Creates

| Component | Purpose |
|-----------|---------|
| VPC (3 AZs) | Network isolation for cluster |
| Public/Private Subnets | Worker nodes in private, LB in public |
| NAT Gateway | Outbound internet for private subnets |
| EKS Cluster | Kubernetes control plane |
| Managed Node Group | Worker nodes (EC2 instances) |
| EKS Add-ons | coredns, kube-proxy, vpc-cni |
| Cluster Autoscaler IRSA | Auto-scaling worker nodes |
| IAM Roles | Pod-level AWS permissions |

---

## 2. Architecture Deep Dive

### Complete Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              AWS Cloud                                       │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │                              VPC (10.20.0.0/16)                       │   │
│  │                                                                       │   │
│  │   ┌─────────────────┐   ┌─────────────────┐   ┌─────────────────┐    │   │
│  │   │     AZ-1        │   │     AZ-2        │   │     AZ-3        │    │   │
│  │   │                 │   │                 │   │                 │    │   │
│  │   │ ┌─────────────┐ │   │ ┌─────────────┐ │   │ ┌─────────────┐ │    │   │
│  │   │ │   Public    │ │   │ │   Public    │ │   │ │   Public    │ │    │   │
│  │   │ │   Subnet    │ │   │ │   Subnet    │ │   │ │   Subnet    │ │    │   │
│  │   │ │ 10.20.128.0 │ │   │ │ 10.20.144.0 │ │   │ │ 10.20.160.0 │ │    │   │
│  │   │ │    /20      │ │   │ │    /20      │ │   │ │    /20      │ │    │   │
│  │   │ └──────┬──────┘ │   │ └──────┬──────┘ │   │ └──────┬──────┘ │    │   │
│  │   │        │        │   │        │        │   │        │        │    │   │
│  │   │ ┌──────▼──────┐ │   │ ┌──────▼──────┐ │   │ ┌──────▼──────┐ │    │   │
│  │   │ │   Private   │ │   │ │   Private   │ │   │ │   Private   │ │    │   │
│  │   │ │   Subnet    │ │   │ │   Subnet    │ │   │ │   Subnet    │ │    │   │
│  │   │ │ 10.20.0.0   │ │   │ │ 10.20.16.0  │ │   │ │ 10.20.32.0  │ │    │   │
│  │   │ │    /20      │ │   │ │    /20      │ │   │ │    /20      │ │    │   │
│  │   │ │             │ │   │ │             │ │   │ │             │ │    │   │
│  │   │ │ ┌─────────┐ │ │   │ │ ┌─────────┐ │ │   │ │ ┌─────────┐ │ │    │   │
│  │   │ │ │ Worker  │ │ │   │ │ │ Worker  │ │ │   │ │ │ Worker  │ │ │    │   │
│  │   │ │ │  Node   │ │ │   │ │ │  Node   │ │ │   │ │ │  Node   │ │ │    │   │
│  │   │ │ │ (EC2)   │ │ │   │ │ │ (EC2)   │ │ │   │ │ │ (EC2)   │ │ │    │   │
│  │   │ │ └─────────┘ │ │   │ │ └─────────┘ │ │   │ │ └─────────┘ │ │    │   │
│  │   │ └─────────────┘ │   │ └─────────────┘ │   │ └─────────────┘ │    │   │
│  │   │        │        │   │        │        │   │        │        │    │   │
│  │   └────────┼────────┘   └────────┼────────┘   └────────┼────────┘    │   │
│  │            │                     │                     │             │   │
│  │            └─────────────────────┼─────────────────────┘             │   │
│  │                                  │                                    │   │
│  │                        ┌─────────▼─────────┐                          │   │
│  │                        │    NAT Gateway    │                          │   │
│  │                        │  (Outbound only)  │                          │   │
│  │                        └─────────┬─────────┘                          │   │
│  │                                  │                                    │   │
│  │                        ┌─────────▼─────────┐                          │   │
│  │                        │   Internet Gateway │                          │   │
│  │                        └─────────┬─────────┘                          │   │
│  │                                  │                                    │   │
│  └──────────────────────────────────┼────────────────────────────────────┘   │
│                                     │                                        │
│  ┌──────────────────────────────────┼────────────────────────────────────┐  │
│  │                         EKS Control Plane                              │  │
│  │                    ┌─────────────────────────┐                          │  │
│  │                    │   Kubernetes API Server  │◄────── Developer       │  │
│  │                    │   (Managed by AWS)       │        (kubectl)       │  │
│  │                    │                          │                          │  │
│  │                    │   ┌─────────────────┐   │                          │  │
│  │                    │   │  etcd Cluster   │   │   (AWS manages)          │  │
│  │                    │   │  (3 replicas)   │   │                          │  │
│  │                    │   └─────────────────┘   │                          │  │
│  │                    │                          │                          │  │
│  │                    │   ┌─────────────────┐   │                          │  │
│  │                    │   │  Scheduler      │   │                          │  │
│  │                    │   │  Controller     │   │                          │  │
│  │                    │   │  Manager        │   │                          │  │
│  │                    │   └─────────────────┘   │                          │  │
│  │                    └─────────────────────────┘                          │  │
│  │                                                                        │  │
│  │                    ┌─────────────────────────┐                          │  │
│  │                    │   OIDC Provider        │◄── IRSA (Pod IAM)        │  │
│  │                    │   (For IRSA)           │                          │  │
│  │                    └─────────────────────────┘                          │  │
│  └────────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐  │
│  │                           Add-ons                                       │  │
│  │  ┌────────────┐  ┌────────────┐  ┌────────────┐                        │  │
│  │  │ CoreDNS    │  │ kube-proxy │  │  VPC CNI   │                        │  │
│  │  │ (DNS)      │  │ (Network)  │  │ (Pod Net)  │                        │  │
│  │  └────────────┘  └────────────┘  └────────────┘                        │  │
│  └────────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐  │
│  │                      Cluster Autoscaler                                 │  │
│  │  ┌─────────────────────────────────────────────────────────────────┐   │  │
│  │  │  Watches for unschedulable pods → Adds/removes worker nodes     │   │  │
│  │  └─────────────────────────────────────────────────────────────────┘   │  │
│  └────────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        Who Manages What?                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  AWS MANAGES:                      YOU MANAGE:                             │
│  ─────────────                     ─────────────                            │
│  • Kubernetes API Server           • Worker Nodes (EC2)                     │
│  • etcd (distributed key-value)    • Pod deployments                       │
│  • Scheduler                       • Services & Ingress                    │
│  • Controller Manager              • IAM Roles (IRSA)                      │
│  • kube-proxy (via add-on)         • Cluster Autoscaler                    │
│  • VPC CNI (via add-on)            • Application security                  │
│  • CoreDNS (via add-on)            • Monitoring & logging                  │
│                                                                             │
│  SHARED RESPONSIBILITY:                                                     │
│  ─────────────────────                                                      │
│  • Security groups (you configure, AWS enforces)                           │
│  • IAM roles for service accounts (you create, AWS validates)              │
│  • Node group scaling (you define min/max, Autoscaler adjusts)             │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Networking Layer

### VPC Design

#### Why 3 Availability Zones?

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     High Availability Pattern                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Single AZ (BAD):                                                          │
│  ┌──────────────────┐                                                       │
│  │      AZ-1        │  ← If AZ fails, entire cluster goes down            │
│  │  [Node] [Node]   │                                                       │
│  └──────────────────┘                                                       │
│                                                                             │
│  Multiple AZs (GOOD):                                                       │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐                                     │
│  │  AZ-1   │  │  AZ-2   │  │  AZ-3   │  ← If one AZ fails, pods reschedule│
│  │ [Node]  │  │ [Node]  │  │ [Node]  │    to other AZs                     │
│  └─────────┘  └─────────┘  └─────────┘                                     │
│                                                                             │
│  EKS Control Plane:                                                        │
│  • Runs across 3 AZs automatically                                          │
│  • Your nodes should match for latency and availability                     │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### Subnet Strategy

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         Subnet CIDR Strategy                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  VPC CIDR: 10.20.0.0/16 (65,536 IPs)                                        │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    Private Subnets (Worker Nodes)                    │   │
│  │                                                                      │   │
│  │  AZ-1: 10.20.0.0/20    (4,096 IPs)  ← Nodes run here                │   │
│  │  AZ-2: 10.20.16.0/20   (4,096 IPs)                                  │   │
│  │  AZ-3: 10.20.32.0/20   (4,096 IPs)                                  │   │
│  │                                                                      │   │
│  │  Total Private: 12,288 IPs available for pods                        │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    Public Subnets (Load Balancers)                   │   │
│  │                                                                      │   │
│  │  AZ-1: 10.20.128.0/20  (4,096 IPs)  ← ALB/NLB/IGW                    │   │
│  │  AZ-2: 10.20.144.0/20  (4,096 IPs)                                  │   │
│  │  AZ-3: 10.20.160.0/20  (4,096 IPs)                                  │   │
│  │                                                                      │   │
│  │  Total Public: 12,288 IPs available for LB endpoints                │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  Why Separate Private and Public?                                          │
│  ─────────────────────────────────                                          │
│  • Worker nodes have no public IPs → More secure                            │
│  • Load balancers in public subnets → Expose services                      │
│  • NAT Gateway → Outbound internet for updates                             │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### NAT Gateway Explained

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          NAT Gateway Flow                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Private Subnet (10.20.0.0/20)                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  Worker Node (no public IP)                                         │   │
│  │  Needs:                                                              │   │
│  │  • Pull container images from Docker Hub                             │   │
│  │  • Download packages from apt/yum                                    │   │
│  │  • Connect to AWS APIs                                               │   │
│  └──────────────────────────────┬──────────────────────────────────────┘   │
│                                 │                                           │
│                                 │ Outbound request                          │
│                                 ▼                                           │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  NAT Gateway (in public subnet)                                      │   │
│  │  • Receives private IP request                                       │   │
│  │  • Translates to public IP                                           │   │
│  │  • Forwards to internet                                              │   │
│  │  • Returns response to private IP                                    │   │
│  └──────────────────────────────┬──────────────────────────────────────┘   │
│                                 │                                           │
│                                 ▼                                           │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  Internet Gateway → Internet                                         │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  Cost: ~$0.045/hour + $0.045/GB data processed                             │
│  For HA: 3 NAT Gateways (one per AZ) = ~$100/month                         │
│  For Dev: 1 NAT Gateway (shared) = ~$32/month                               │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### Subnet Tags (Critical for EKS)

```hcl
# Required for AWS Load Balancer Controller
public_subnet_tags = {
  "kubernetes.io/role/elb" = "1"           # For public load balancers
}

private_subnet_tags = {
  "kubernetes.io/role/internal-elb" = "1"  # For internal load balancers
}

# Required for EKS
tags = {
  "kubernetes.io/cluster/${var.cluster_name}" = "shared"
}
```

| Tag | Purpose |
|-----|---------|
| `kubernetes.io/cluster/<name>` | Identifies subnets for EKS |
| `kubernetes.io/role/elb` | Public ALB/NLB placement |
| `kubernetes.io/role/internal-elb` | Internal ALB/NLB placement |

---

## 4. EKS Control Plane

### Control Plane Components

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     EKS Control Plane (AWS Managed)                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                        API Server                                    │   │
│  │                                                                      │   │
│  │  • REST API for all Kubernetes operations                           │   │
│  │  • Authentication via IAM or OIDC                                   │   │
│  │  • Authorization via RBAC                                            │   │
│  │  • Admission control (validates requests)                           │   │
│  │  • Rate limiting                                                     │   │
│  │                                                                      │   │
│  │  Endpoint: https://<cluster-id>.gr7.<region>.eks.amazonaws.com      │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                          etcd                                        │   │
│  │                                                                      │   │
│  │  • Distributed key-value store                                      │   │
│  │  • Stores all cluster state (pods, services, configs)              │   │
│  │  • 3 replicas across AZs for HA                                     │   │
│  │  • Automatic backups (AWS managed)                                  │   │
│  │  • No direct access (via API server only)                           │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                       Scheduler                                      │   │
│  │                                                                      │   │
│  │  • Watches for new pods with no node assignment                     │   │
│  │  • Scores nodes based on:                                           │   │
│  │    - Resource requirements (CPU, memory)                            │   │
│  │    - Affinity/anti-affinity rules                                   │   │
│  │    - Taints and tolerations                                         │   │
│  │    - Node selectors                                                 │   │
│  │  • Binds pod to best-fit node                                       │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    Controller Manager                                │   │
│  │                                                                      │   │
│  │  • Runs controller processes:                                       │   │
│  │    - Node Controller: Node health monitoring                        │   │
│  │    - Replication Controller: Pod replica management                │   │
│  │    - Endpoints Controller: Service -> Pod mapping                  │   │
│  │    - Service Account Controller: Default accounts                  │   │
│  │  • Watches state and makes changes to reach desired state           │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                      Cloud Controller                                │   │
│  │                                                                      │   │
│  │  • AWS-specific controllers:                                        │   │
│  │    - Route Controller: Updates AWS route tables                     │   │
│  │    - Service Controller: Creates AWS load balancers                 │   │
│  │    - Node Controller: Updates node labels/annotations               │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### API Server Access Configuration

```hcl
module "eks" {
  # ... other config ...

  # Public endpoint (accessible from internet)
  cluster_endpoint_public_access           = true
  cluster_endpoint_public_access_cidrs    = ["0.0.0.0/0"]  # ⚠️ Open to all

  # Private endpoint (accessible within VPC)
  # cluster_endpoint_private_access = true  # Uncomment for private-only
}
```

#### Public vs Private API Endpoint

| Access Type | Use Case | Security |
|-------------|----------|----------|
| **Public Only** | Development, learning | API accessible from internet |
| **Private Only** | High security | Only accessible within VPC |
| **Both** | Hybrid setups | Public for admins, private for pods |

#### Security Best Practice: Restrict CIDRs

```hcl
# Production: Restrict to known IPs
cluster_endpoint_public_access_cidrs = [
  "203.0.113.0/24",    # Office IP range
  "198.51.100.0/24",   # VPN IP range
]

# Or use private only (no public access)
cluster_endpoint_public_access           = false
cluster_endpoint_private_access          = true
```

### OIDC Provider (IRSA)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    OIDC Provider for IRSA                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  What is IRSA?                                                              │
│  ─────────────                                                              │
│  IAM Roles for Service Accounts (IRSA) allows Kubernetes pods to           │
│  assume AWS IAM roles without storing credentials in pods.                  │
│                                                                             │
│  How it works:                                                              │
│  ───────────────                                                            │
│                                                                             │
│  ┌─────────────┐     1. Pod requests AWS API     ┌─────────────────┐      │
│  │   Pod       │ ──────────────────────────────► │   AWS Service   │      │
│  │ (with SA)   │                                 │   (S3, EC2)     │      │
│  │             │                                 └─────────────────┘      │
│  │ annotation: │     2. Service checks OIDC              ▲              │
│  │ eks.amazonaws │   provider                            │              │
│  │ .com/role-arn │                                       │              │
│  └─────────────┘     3. OIDC validates                 │              │
│                          JWT token                       │              │
│                          from pod                        │              │
│                                                          │              │
│  ┌─────────────────┐     4. AWS issues temp            │              │
│  │  OIDC Provider  │    credentials                     │              │
│  │  (EKS managed)  │ ────────────────────────────────────┘              │
│  └─────────────────┘                                                        │
│                                                                             │
│  Benefits:                                                                  │
│  ──────────                                                                 │
│  ✅ No AWS credentials stored in pods/secrets                             │
│  ✅ Temporary credentials (rotated automatically)                          │
│  ✅ Fine-grained permissions per service account                           │
│  ✅ Auditable via CloudTrail                                                │
│                                                                             │
│  Created automatically by EKS module:                                       │
│  enable_irsa = true                                                         │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 5. Worker Nodes

### Managed Node Groups vs Self-Managed

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Node Group Comparison                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Managed Node Groups (RECOMMENDED)          Self-Managed Nodes               │
│  ─────────────────────────────────────     ─────────────────────────────     │
│  ✅ AWS manages lifecycle                  ❌ You manage everything         │
│  ✅ Auto-upgrade available                 ❌ Manual upgrades                │
│  ✅ Automatic security patches            ❌ Manual patching                │
│  ✅ Health checks                          ❌ You monitor health             │
│  ✅ Graceful draining on update           ❌ Manual draining                │
│  ✅ Console/CLI visibility                 ❌ Limited visibility             │
│                                                                             │
│  Use Self-Managed Only When:                                                │
│  ──────────────────────────                                                 │
│  • Need custom AMI with pre-installed software                             │
│  • Require specific instance store configuration                           │
│  • Using GPU instances with custom drivers                                  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Node Group Configuration

```hcl
eks_managed_node_groups = {
  default = {
    # Instance configuration
    instance_types = ["t3.medium"]    # 2 vCPU, 4 GB RAM
    capacity_type  = "ON_DEMAND"       # ON_DEMAND or SPOT
    disk_size      = 30                # GB, minimum 20

    # Scaling configuration
    min_size      = 1                  # Minimum nodes (cost control)
    max_size      = 3                  # Maximum nodes (capacity limit)
    desired_size  = 2                  # Starting node count

    # Labels (for scheduling)
    labels = {
      role = "general"                 # kubectl get nodes -l role=general
    }

    # Taints (for dedicated workloads)
    # taints = [
    #   {
    #     key    = "dedicated"
    #     value  = "gpu"
    #     effect = "NO_SCHEDULE"
    #   }
    # ]
  }
}
```

### Instance Type Selection

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      Instance Type Guide                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  General Purpose (Balanced):                                                │
│  ─────────────────────────                                                  │
│  t3.medium   - 2 vCPU, 4 GB   - $0.04/h - Dev/Testing                      │
│  t3.large    - 2 vCPU, 8 GB   - $0.08/h - Small workloads                  │
│  m5.large    - 2 vCPU, 8 GB   - $0.10/h - Production                       │
│  m5.xlarge   - 4 vCPU, 16 GB  - $0.20/h - Medium workloads                 │
│                                                                             │
│  Compute Optimized (High CPU):                                              │
│  ─────────────────────────────                                              │
│  c5.large    - 2 vCPU, 4 GB   - $0.09/h - CPU-intensive                    │
│  c5.xlarge   - 4 vCPU, 8 GB   - $0.17/h - Batch processing                 │
│                                                                             │
│  Memory Optimized (High RAM):                                               │
│  ──────────────────────────────                                             │
│  r5.large    - 2 vCPU, 16 GB  - $0.13/h - Databases, caching               │
│  r5.xlarge   - 4 vCPU, 32 GB  - $0.25/h - In-memory processing             │
│                                                                             │
│  Cost Optimization:                                                         │
│  ───────────────────                                                        │
│  SPOT instances - 70-90% cheaper, can be interrupted                        │
│  Use for: Fault-tolerant, stateless workloads                               │
│  Avoid for: Databases, stateful applications                                │
│                                                                             │
│  Recommendation:                                                             │
│  Dev:     t3.medium (SPOT)        - ~$20/month                              │
│  Staging: t3.medium (ON_DEMAND)   - ~$30/month                              │
│  Prod:    m5.large (ON_DEMAND)     - ~$75/month                             │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Node Sizing Formula

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     Node Sizing Calculation                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Step 1: Calculate workload requirements                                    │
│  ───────────────────────────────────────────                                │
│                                                                             │
│  Example: Microservices deployment                                         │
│  • 10 services × 2 replicas = 20 pods                                     │
│  • Each pod: 500m CPU, 512Mi memory                                       │
│  • Total: 10 vCPU, 10 GB memory                                           │
│                                                                             │
│  Step 2: Account for system overhead                                       │
│  ────────────────────────────────────────                                   │
│                                                                             │
│  Kubernetes system pods (kube-proxy, coredns): ~1 vCPU, 1 GB               │
│  Operating system overhead: ~5-10% of node resources                       │
│                                                                             │
│  Adjusted total: 11 vCPU, 12 GB                                            │
│                                                                             │
│  Step 3: Choose instance type                                              │
│  ─────────────────────────────                                              │
│                                                                             │
│  Option A: 6 × m5.xlarge (4 vCPU, 16 GB each) = 24 vCPU, 96 GB            │
│  Option B: 3 × m5.2xlarge (8 vCPU, 32 GB each) = 24 vCPU, 96 GB            │
│  Option C: 12 × t3.medium (2 vCPU, 4 GB each) = 24 vCPU, 48 GB ⚠️         │
│                                                                             │
│  Consider:                                                                  │
│  • Fewer larger nodes = simpler management, less overhead                 │
│  • More smaller nodes = better fault isolation, more overhead             │
│                                                                             │
│  Step 4: Set autoscaling limits                                            │
│  ──────────────────────────────                                             │
│                                                                             │
│  min_size = 2 (minimum for HA)                                             │
│  max_size = 10 (maximum budget)                                            │
│  desired_size = 4 (expected load)                                          │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 6. EKS Add-ons

### What are EKS Add-ons?

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        EKS Add-ons Overview                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  EKS Add-ons are pre-installed, AWS-managed Kubernetes components:         │
│                                                                             │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                     Without Add-ons                                   │  │
│  │                                                                       │  │
│  │  ❌ You install vpc-cni, coredns, kube-proxy manually                │  │
│  │  ❌ You handle upgrades and security patches                         │  │
│  │  ❌ You configure and troubleshoot                                   │  │
│  │  ❌ Versions can conflict with EKS version                            │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                     With Add-ons                                      │  │
│  │                                                                       │  │
│  │  ✅ AWS installs and configures                                      │  │
│  │  ✅ Automatic security patches                                        │  │
│  │  ✅ Version compatibility checked                                     │  │
│  │  ✅ Managed through Terraform/console                                │  │
│  │  ✅ Update with: terraform apply or console                          │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Core Add-ons Explained

#### 1. VPC CNI (Amazon VPC Container Network Interface)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            VPC CNI                                           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Purpose: Assigns IP addresses to pods from VPC                            │
│                                                                             │
│  How it works:                                                              │
│  ───────────────                                                            │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                       Node (EC2)                                     │   │
│  │                                                                      │   │
│  │  Primary ENI:                                                        │   │
│  │  ┌─────────────────────────────────────────────────────────────┐    │   │
│  │  │ eth0: 10.20.0.10 (primary IP)                               │    │   │
│  │  │                                                              │    │   │
│  │  │ Secondary IPs:                                               │    │   │
│  │  │ 10.20.0.11 → pod-1 (nginx)                                   │    │   │
│  │  │ 10.20.0.12 → pod-2 (redis)                                   │    │   │
│  │  │ 10.20.0.13 → pod-3 (app)                                     │    │   │
│  │  └─────────────────────────────────────────────────────────────┘    │   │
│  │                                                                      │   │
│  │  Secondary ENI (if needed):                                         │   │
│  │  ┌─────────────────────────────────────────────────────────────┐    │   │
│  │  │ eth1: 10.20.0.20 → pod-4 (sidecar)                          │    │   │
│  │  │        10.20.0.21 → pod-5 (sidecar)                         │    │   │
│  │  └─────────────────────────────────────────────────────────────┘    │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  Key configuration:                                                        │
│  ───────────────────                                                        │
│  WARM_ENI_TARGET = 1 (default)     # Pre-allocate 1 ENI for fast pod start │
│  WARM_IP_TARGET = 0 (default)      # Pre-allocate IPs                      │
│                                                                             │
│  Each instance type has max ENIs and IPs per ENI:                           │
│  t3.medium: 3 ENIs, 6 IPs/ENI = max 18 pods (minus system pods)            │
│  m5.large:  3 ENIs, 10 IPs/ENI = max 30 pods                               │
│                                                                             │
│  Best Practices:                                                            │
│  ────────────────                                                           │
│  • Use latest version for security patches                                  │
│  • Monitor IP exhaustion with Custom Networking for large clusters         │
│  • Consider Security Groups for Pods (for microsegmentation)               │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### 2. CoreDNS

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            CoreDNS                                           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Purpose: DNS resolution for services and pods                              │
│                                                                             │
│  What it does:                                                              │
│  ───────────────                                                            │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  Service Discovery in Kubernetes                                     │   │
│  │                                                                      │   │
│  │  Service: my-service.default.svc.cluster.local                      │   │
│  │           └────────┘ └─────┘ └───┘ └──────────┘                     │   │
│  │              │          │       │        │                           │   │
│  │           Service    Namespace  │    Domain                         │   │
│  │                                 │                                    │   │
│  │  Pod:       10-20-0-5.default.pod.cluster.local                     │   │
│  │              │                                                     │   │
│  │           Pod IP                                                    │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  DNS Resolution Flow:                                                       │
│  ────────────────────                                                       │
│                                                                             │
│  1. Pod wants to reach my-service                                          │
│  2. Query: my-service.default.svc.cluster.local                            │
│  3. CoreDNS resolves to ClusterIP: 10.100.0.50                             │
│  4. kube-proxy load balances to pod IPs                                    │
│                                                                             │
│  Example:                                                                   │
│  ──────────                                                                 │
│  # Service DNS                                                              │
│  kubectl run busybox --image=busybox --rm -it -- nslookup my-service       │
│  Server:    10.100.0.10      (CoreDNS ClusterIP)                          │
│  Address:   10.100.0.10                                                    │
│  Name:      my-service.default.svc.cluster.local                          │
│  Address:   10.100.0.50      (Service ClusterIP)                           │
│                                                                             │
│  Configuration:                                                              │
│  ───────────────                                                            │
│  • Runs as 2 replicas by default (HA)                                       │
│  • CoreFile: /etc/coredns/Corefile (configmap)                            │
│  • Can add custom DNS zones                                                 │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### 3. kube-proxy

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           kube-proxy                                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Purpose: Maintains network rules for Service load balancing               │
│                                                                             │
│  How it works:                                                              │
│  ───────────────                                                            │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    Service Traffic Flow                              │   │
│  │                                                                      │   │
│  │  Client Pod                                                          │   │
│  │  ┌─────────────┐                                                     │   │
│  │  │  Request:  │                                                     │   │
│  │  │  10.100.0.50:80                                                  │   │
│  │  │  (ClusterIP)                                                      │   │
│  │  └──────┬──────┘                                                     │   │
│  │         │                                                            │   │
│  │         ▼                                                            │   │
│  │  ┌─────────────────────────────────────────────────────────────────┐│   │
│  │  │                     kube-proxy                                   ││   │
│  │  │                                                                  ││   │
│  │  │  iptables rules (on each node):                                 ││   │
│  │  │  - Service 10.100.0.50 → Backend pods:                          ││   │
│  │  │    10.20.0.5:8080  (pod-1)                                       ││   │
│  │  │    10.20.1.8:8080  (pod-2)                                       ││   │
│  │  │    10.20.2.3:8080  (pod-3)                                       ││   │
│  │  │                                                                  ││   │
│  │  │  Load balancing: Random or Round-robin                          ││   │
│  │  └─────────────────────────────────────────────────────────────────┘│   │
│  │         │                                                            │   │
│  │         ▼                                                            │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                 │   │
│  │  │   Pod 1     │  │   Pod 2     │  │   Pod 3     │                 │   │
│  │  │ 10.20.0.5   │  │ 10.20.1.8   │  │ 10.20.2.3   │                 │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘                 │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  Modes:                                                                     │
│  ──────────                                                                  │
│  iptables (default): Uses Linux iptables for routing                       │
│  IPVS: Better performance for large clusters (thousands of services)       │
│                                                                             │
│  Note: EKS Fargate and newer EKS versions are moving to eBPF-based          │
│  networking which may eventually replace kube-proxy                         │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Add-on Configuration

```hcl
module "eks" {
  # ... other config ...

  cluster_addons = {
    coredns = {
      most_recent = true                    # Auto-update to latest
      # version    = "v1.11.1-eksbuild.9"   # Or pin specific version
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }
}
```

### Add-on Version Compatibility

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                 EKS Add-on Version Matrix                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Kubernetes Version │ vpc-cni    │ coredns     │ kube-proxy                │
│  ───────────────────┼────────────┼─────────────┼────────────────           │
│  1.28               │ v1.14.x    │ v1.10.x     │ v1.28.x                   │
│  1.29               │ v1.15.x    │ v1.11.x     │ v1.29.x                   │
│  1.30               │ v1.16.x    │ v1.11.x     │ v1.30.x                   │
│  1.31               │ v1.17.x    │ v1.11.x     │ v1.31.x                   │
│                                                                             │
│  Best Practice:                                                             │
│  ──────────────                                                             │
│  • Use most_recent = true for automatic updates                           │
│  • Pin version when you need stability or testing                          │
│  • Check compatibility before EKS upgrades                                  │
│                                                                             │
│  Commands:                                                                   │
│  ──────────                                                                  │
│  # List available add-on versions                                           │
│  aws eks describe-addon-versions \                                          │
│    --addon-name vpc-cni \                                                   │
│    --kubernetes-version 1.31                                                │
│                                                                             │
│  # Check current add-on status                                              │
│  kubectl get pods -n kube-system                                            │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 7. Cluster Autoscaler

### What is Cluster Autoscaler?

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Cluster Autoscaler Overview                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Purpose: Automatically adjusts node count based on workload demand         │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    Scale Up Scenario                                  │   │
│  │                                                                      │   │
│  │  1. Deployment creates 5 new pods                                    │   │
│  │  2. Scheduler cannot place 3 pods (insufficient CPU/memory)         │   │
│  │  3. Pods become "Pending" status                                     │   │
│  │  4. Autoscaler detects unschedulable pods                            │   │
│  │  5. Autoscaler requests new node from ASG                            │   │
│  │  6. Node joins cluster, pods get scheduled                           │   │
│  │                                                                      │   │
│  │  Timeline: 2-5 minutes from Pending to Running                       │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                   Scale Down Scenario                                │   │
│  │                                                                      │   │
│  │  1. Pods finish or are deleted                                       │   │
│  │  2. Node utilization drops below threshold (default 50%)             │   │
│  │  3. Autoscaler waits 10 minutes (cool-down)                          │   │
│  │  4. If still underutilized, node is cordoned and drained             │   │
│  │  5. Node is terminated                                               │   │
│  │                                                                      │   │
│  │  Safe guards:                                                         │   │
│  │  • Never scale down below min_size                                    │   │
│  │  • Don't remove nodes with local storage by default                  │   │
│  │  • Respect PDB (Pod Disruption Budget)                               │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### How It Works with EKS

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    EKS + Cluster Autoscaler                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Requirements:                                                              │
│  ─────────────                                                              │
│  1. Managed Node Group (or ASG for self-managed)                           │
│  2. Tags on node group for discovery                                        │
│  3. IAM Role for Service Account (IRSA)                                    │
│  4. Cluster Autoscaler deployment                                          │
│                                                                             │
│  Node Group Tags (automatic):                                               │
│  ──────────────────────────────                                              │
│  k8s.io/cluster-autoscaler/enabled = "true"                                 │
│  k8s.io/cluster-autoscaler/<cluster-name> = "owned"                         │
│                                                                             │
│  IAM Permissions (via IRSA):                                                │
│  ────────────────────────────                                                │
│  autoscaling:DescribeAutoScalingGroups                                     │
│  autoscaling:DescribeAutoScalingInstances                                   │
│  autoscaling:DescribeLaunchConfigurations                                   │
│  autoscaling:DescribeTags                                                   │
│  autoscaling:SetDesiredCapacity                                             │
│  autoscaling:TerminateInstanceInAutoScalingGroup                            │
│  ec2:DescribeLaunchTemplateVersions                                         │
│  ec2:DescribeInstanceTypes                                                  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Implementation

```hcl
# In main.tf - Tags for Cluster Autoscaler
module "eks" {
  # ... other config ...

  tags = {
    "k8s.io/cluster-autoscaler/enabled" = "true"
  }
}
```

```hcl
# In cluster-autoscaler.tf - IRSA Role
module "cluster_autoscaler_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${var.cluster_name}-cluster-autoscaler"

  oidc_providers = {
    main = {
      provider_arn                = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:cluster-autoscaler"]
    }
  }

  attach_cluster_autoscaler_policy = true
  cluster_autoscaler_cluster_names  = [var.cluster_name]
}
```

### Autoscaling Parameters

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Node Group Scaling Settings                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  min_size = 1                                                               │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  Minimum number of nodes ALWAYS running                              │   │
│  │  • Ensures cluster never scales to zero                              │   │
│  │  • Set to 0 for "scale to zero" (dev environments)                   │   │
│  │  • Cost: $30-100/month per node (instance type)                      │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  max_size = 3                                                               │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  Maximum number of nodes (hard limit)                                │   │
│  │  • Prevents runaway scaling                                          │   │
│  │  • Protects AWS account limits                                        │   │
│  │  • Set based on budget constraints                                   │   │
│  │  • Cost: min_size × price to max_size × price                        │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  desired_size = 2                                                           │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  Initial/expected number of nodes                                    │   │
│  │  • Starting point when cluster is created                            │   │
│  │  • Autoscaler can change this (within min/max)                       │   │
│  │  • Manual changes override autoscaler                                │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  Example Configurations:                                                    │
│  ────────────────────────                                                   │
│                                                                             │
│  Development (cost-optimized):                                              │
│    min_size = 0, max_size = 2, desired_size = 0                            │
│    → Scales to zero when unused, max 2 nodes                               │
│                                                                             │
│  Staging:                                                                   │
│    min_size = 1, max_size = 3, desired_size = 1                           │
│    → Always 1 node, scales up to 3 when needed                             │
│                                                                             │
│  Production:                                                                │
│    min_size = 3, max_size = 10, desired_size = 3                           │
│    → Minimum 3 nodes for HA, scales to 10                                  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Deploying Cluster Autoscaler

```yaml
# After cluster creation, apply the manifest:
# terraform output -raw cluster_autoscaler_manifest | kubectl apply -f -

# Key configuration in the deployment:
spec:
  containers:
    - name: cluster-autoscaler
      command:
        - ./cluster-autoscaler
        - --v=4                          # Log level
        - --cloud-provider=aws            # AWS-specific
        - --skip-nodes-with-local-storage=false
        - --expander=least-waste          # Scale-up strategy
        - --balance-similar-node-groups
        - --node-group-auto-discovery=asg:tag=k8s.io/cluster-autoscaler/enabled
```

### Verification Commands

```bash
# Check autoscaler logs
kubectl logs -n kube-system deployment/cluster-autoscaler

# Check node scaling
kubectl get nodes --watch

# Check pending pods (should trigger scale-up)
kubectl get pods --field-selector=status.phase=Pending

# Check ASG (via AWS CLI)
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names <node-group-name>

# Force scale-up test
kubectl run test --image=nginx --replicas=100 --requests=cpu=1
```

---

## 8. IAM Roles for Service Accounts (IRSA)

### Deep Dive into IRSA

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    IRSA Architecture                                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Traditional Approach (DEPRECATED):                                         │
│  ──────────────────────────────────                                         │
│  ┌─────────────────┐                                                        │
│  │  Node IAM Role  │ ← All pods inherit node role                          │
│  │  S3FullAccess   │ ← Over-permissive                                      │
│  │  EC2FullAccess  │ ← Security risk                                        │
│  └─────────────────┘                                                        │
│  Problem: Every pod has full access                                         │
│                                                                             │
│  IRSA Approach (RECOMMENDED):                                               │
│  ────────────────────────────────                                           │
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐ │
│  │                          OIDC Flow                                     │ │
│  │                                                                        │ │
│  │  1. Pod starts with service account                                    │ │
│  │  2. Service account has annotation:                                   │ │
│  │    eks.amazonaws.com/role-arn: arn:aws:iam::123:role/my-role          │ │
│  │  3. Pod receives JWT token from OIDC provider                        │ │
│  │  4. JWT token presented to STS AssumeRoleWithWebIdentity             │ │
│  │  5. AWS validates token against OIDC provider                        │ │
│  │  6. Temporary credentials returned to pod                            │ │
│  │  7. Pod uses credentials for AWS API calls                            │ │
│  │                                                                        │ │
│  └───────────────────────────────────────────────────────────────────────┘ │
│                                                                             │
│  Security Benefits:                                                         │
│  ─────────────────                                                          │
│  ✅ Least privilege: Each pod gets only needed permissions                 │
│  ✅ Auditable: CloudTrail logs show which role did what                    │
│  ✅ Temporary: Credentials expire after 15 minutes                         │
│  ✅ No secrets: No AWS keys stored in pods/ConfigMaps                      │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Implementation Example

```hcl
# Step 1: Create IAM Policy
data "aws_iam_policy_document" "cluster_autoscaler" {
  statement {
    sid    = "ClusterAutoscaler"
    effect = "Allow"

    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:DescribeLaunchConfigurations",
      "autoscaling:DescribeTags",
      "autoscaling:SetDesiredCapacity",
      "autoscaling:TerminateInstanceInAutoScalingGroup",
      "ec2:DescribeLaunchTemplateVersions",
      "ec2:DescribeInstanceTypes"
    ]

    resources = ["*"]
  }
}

# Step 2: Create IAM Role with OIDC Trust
module "cluster_autoscaler_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${var.cluster_name}-cluster-autoscaler"

  oidc_providers = {
    main = {
      provider_arn                = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:cluster-autoscaler"]
    }
  }

  attach_cluster_autoscaler_policy = true
  cluster_autoscaler_cluster_names  = [var.cluster_name]
}

# Step 3: Annotate Service Account
# (In Kubernetes manifest)
# apiVersion: v1
# kind: ServiceAccount
# metadata:
#   name: cluster-autoscaler
#   namespace: kube-system
#   annotations:
#     eks.amazonaws.com/role-arn: <output from module>
```

### Common IRSA Use Cases

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    IRSA Use Cases                                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Add-on                     │ Permissions Needed                            │
│  ───────────────────────────┼─────────────────────────────────────────────  │
│  Cluster Autoscaler          │ autoscaling:*, ec2:Describe*                │
│  AWS Load Balancer Controller│ ec2:*, elasticloadbalancing:*, iam:*       │
│  ExternalDNS                 │ route53:*                                    │
│  EBS CSI Driver              │ ec2:Create*, ec2:Delete*, ec2:Describe*     │
│  EFS CSI Driver              │ elasticfilesystem:*                         │
│  Secrets Store CSI           │ secretsmanager:Get*, kms:Decrypt           │
│                                                                             │
│  Best Practice:                                                              │
│  ──────────────                                                              │
│  • One IAM role per application/service                                     │
│  • Use condition keys to limit scope                                        │
│  • Monitor via CloudTrail                                                   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 9. Security Best Practices

### Security Layers

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Defense in Depth                                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Layer 1: Network Security                                                  │
│  ─────────────────────────────                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  VPC Isolation                                                        │   │
│  │  • Private subnets for worker nodes                                   │   │
│  │  • Security groups (SG) for pod communication                         │   │
│  │  • Network policies (Kubernetes)                                       │   │
│  │  • VPC flow logs for auditing                                        │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  Layer 2: API Server Access                                                 │
│  ────────────────────────────                                               │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  API Endpoint Configuration                                           │   │
│  │  • Public endpoint with CIDR restrictions                           │   │
│  │  • Or private endpoint (VPN/Direct Connect only)                    │   │
│  │  • IAM authentication required                                       │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  Layer 3: Identity & Access                                                 │
│  ─────────────────────────────                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  IAM + RBAC                                                           │   │
│  │  • IAM users/roles authenticate to EKS                               │   │
│  │  • RBAC controls what they can do in cluster                         │   │
│  │  • IRSA for pod-level permissions                                    │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  Layer 4: Workload Security                                                 │
│  ─────────────────────────────                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  Pod Security                                                         │   │
│  │  • Run as non-root                                                   │   │
│  │  • Read-only root filesystem                                         │   │
│  │  • Drop all capabilities                                              │   │
│  │  • Use security contexts                                             │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  Layer 5: Data Security                                                    │
│  ──────────────────────────                                                 │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  Encryption                                                           │   │
│  │  • EBS volumes encrypted (KMS)                                       │   │
│  │  • Secrets encryption at rest (etcd)                                  │   │
│  │  • TLS for in-transit communication                                  │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### API Endpoint Security

```hcl
# Option 1: Public endpoint with IP restrictions (Development)
cluster_endpoint_public_access           = true
cluster_endpoint_public_access_cidrs    = [
  "203.0.113.0/24",    # Office IP range
  "198.51.100.0/24",   # VPN IP range
]

# Option 2: Private endpoint only (Production)
cluster_endpoint_public_access           = false
cluster_endpoint_private_access          = true
# Access via: VPN, Direct Connect, or Bastion host
```

### Security Groups

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Security Group Rules                                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Control Plane Security Group (AWS Managed):                               │
│  ───────────────────────────────────────────                                │
│  Inbound:                                                                   │
│    • Port 443 from worker nodes (API calls)                                │
│    • Port 443 from CIDR blocks (kubectl)                                   │
│                                                                             │
│  Worker Node Security Group:                                               │
│  ─────────────────────────────────                                          │
│  Inbound:                                                                   │
│    • Port 443 from control plane (API calls)                               │
│    • Port 10250 from control plane (kubelet)                               │
│    • Port 1025x from control plane (logs)                                  │
│    • All ports from self (pod-to-pod within node)                         │
│    • Application ports from ALB/NLB                                        │
│                                                                             │
│  EKS automatically creates and manages these security groups:              │
│  • eks-cluster-sg-<cluster-name> (control plane)                          │
│  • eks-nodegroup-<nodegroup-name> (worker nodes)                          │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Pod Security Standards

```yaml
# Pod Security Policy (Restricted)
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod
spec:
  securityContext:
    runAsNonRoot: true          # Don't run as root
    runAsUser: 1000             # Specific user ID
    fsGroup: 1000               # File system group
    seccompProfile:
      type: RuntimeDefault     # Use default seccomp profile
  containers:
    - name: app
      image: nginx
      securityContext:
        allowPrivilegeEscalation: false  # No sudo
        readOnlyRootFilesystem: true      # Immutable filesystem
        runAsNonRoot: true
        capabilities:
          drop:
            - ALL                      # Drop all Linux capabilities
```

---

## 10. Cost Optimization

### Cost Breakdown

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Monthly Cost Estimate (24/7)                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Fixed Costs (Always Running):                                              │
│  ─────────────────────────────────                                          │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  EKS Control Plane         $0.10/hour × 730 =      $73.00/month     │   │
│  │  NAT Gateway               $0.045/hour × 730 =      $32.85/month     │   │
│  │  NAT Gateway Data          ~$5-10/month            $10.00/month     │   │
│  │  ─────────────────────────────────────────────────────────────────  │   │
│  │  Subtotal Fixed:                                  $115.85/month     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  Variable Costs (Depends on Usage):                                        │
│  ─────────────────────────────────────                                      │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  t3.medium nodes (×2)      $0.042/hour × 730 × 2 = $61.32/month     │   │
│  │  EBS volumes (30GB × 2)    $0.10/GB/month × 60 =   $6.00/month      │   │
│  │  VPC (Data transfer)       ~$5/month              $5.00/month       │   │
│  │  ─────────────────────────────────────────────────────────────────  │   │
│  │  Subtotal Variable:                               $72.32/month      │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  Total Estimate: ~$188/month (24/7)                                        │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Cost Reduction Strategies

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Cost Optimization Strategies                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Strategy 1: Destroy When Not in Use (HIGHEST SAVINGS)                     │
│  ──────────────────────────────────────────────────────────                 │
│  Use: Development, Learning                                                │
│  Savings: 70-90%                                                           │
│  Method:                                                                    │
│    terraform destroy  # End of day                                         │
│    terraform apply    # Start of day                                       │
│  Cost: ~$15-25/month (4 hrs/day, 5 days/week)                              │
│                                                                             │
│  Strategy 2: Scale to Zero Nodes                                           │
│  ──────────────────────────────                                             │
│  Use: Staging, Low-traffic workloads                                      │
│  Savings: 40-60%                                                            │
│  Method:                                                                    │
│    min_size = 0, desired_size = 0  # Cluster Autoscaler                    │
│  Cost: Control plane + NAT still running (~$105/month)                    │
│                                                                             │
│  Strategy 3: Spot Instances                                                │
│  ────────────────────────────                                               │
│  Use: Fault-tolerant, stateless workloads                                  │
│  Savings: 70-90% on compute                                                │
│  Method:                                                                    │
│    capacity_type = "SPOT"                                                  │
│  Risk: Instances can be interrupted (2-min notice)                         │
│  Mitigation: Use multiple instance types, Cluster Autoscaler               │
│                                                                             │
│  Strategy 4: Right-Sizing Nodes                                            │
│  ───────────────────────────────                                            │
│  Use: All environments                                                     │
│  Savings: 20-40%                                                            │
│  Method: Monitor actual usage, downsize                                     │
│  Tools: kubectl top, Prometheus, Kubecost                                  │
│                                                                             │
│  Strategy 5: Reserved Instances                                             │
│  ───────────────────────────────                                            │
│  Use: Long-running production clusters                                      │
│  Savings: 30-60%                                                            │
│  Commitment: 1-3 year term                                                 │
│                                                                             │
│  Strategy 6: Single NAT Gateway                                            │
│  ─────────────────────────────                                              │
│  Use: Development, Staging                                                  │
│  Savings: ~$65/month (vs 3 NAT Gateways)                                    │
│  Trade-off: Single point of failure                                        │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Start/Stop Scripts (Cost Savings)

```powershell
# start-cluster.ps1 - Creates infrastructure (~15-20 min)
terraform init
terraform apply

# stop-cluster.ps1 - Destroys infrastructure (stops all costs)
terraform destroy
```

---

## 11. Interview Scenarios

### Scenario 1: Cluster Won't Scale

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  Interview Question: Pods are stuck in Pending state, nodes don't scale.   │
│                      What do you check?                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Answer Structure:                                                          │
│  ──────────────────                                                         │
│                                                                             │
│  1. Check Pod Status:                                                       │
│     kubectl describe pod <pod-name>                                         │
│     → Look for events: "0/2 nodes available: insufficient CPU"             │
│     → Confirms resource shortage, not scheduling issue                     │
│                                                                             │
│  2. Check Cluster Autoscaler logs:                                          │
│     kubectl logs -n kube-system deployment/cluster-autoscaler               │
│     → Look for: "No node group could be scaled"                            │
│     → Check for IAM permission errors                                       │
│                                                                             │
│  3. Check Node Group Configuration:                                         │
│     kubectl get nodes                                                       │
│     kubectl describe node <node-name>                                       │
│     → Check if at max_size limit                                            │
│                                                                             │
│  4. Check ASG in AWS Console:                                               │
│     aws autoscaling describe-auto-scaling-groups                            │
│     → Verify min/max settings                                               │
│     → Check if scaling activities failed                                    │
│                                                                             │
│  5. Common Issues:                                                          │
│     • max_size reached → Increase max_size                                  │
│     • IAM permissions missing → Fix IRSA role                               │
│     • Tags missing on ASG → Add required tags                              │
│     • Instance type unavailable → Use multiple instance types               │
│                                                                             │
│  Bonus: Mention checking instance quotas in the region                      │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Scenario 2: Pods Can't Communicate

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  Interview Question: Pods in different namespaces can't communicate.       │ │
│                      How do you troubleshoot?                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Answer Structure:                                                          │
│  ──────────────────                                                         │
│                                                                             │
│  1. Check DNS Resolution:                                                   │
│     kubectl run test --image=busybox --rm -it -- nslookup my-service.ns     │
│     → Full FQDN: service-name.namespace.svc.cluster.local                 │
│     → Cross-namespace: my-service.other-namespace.svc.cluster.local        │
│                                                                             │
│  2. Check Service Endpoint:                                                 │
│     kubectl get endpoints my-service -n namespace                           │
│     → Should show pod IPs                                                   │
│     → If empty: selector mismatch                                          │
│                                                                             │
│  3. Check Network Policies:                                                  │
│     kubectl get networkpolicy -A                                           │
│     → May block cross-namespace traffic                                     │
│                                                                             │
│  4. Test Connectivity:                                                       │
│     kubectl run test --image=busybox --rm -it --                           │
│       wget -qO- http://my-service.other-namespace:80                       │
│                                                                             │
│  5. Check Security Groups:                                                  │
│     AWS Console → VPC → Security Groups                                     │
│     → Ensure worker node SG allows intra-cluster traffic                   │
│                                                                             │
│  6. Check VPC CNI:                                                          │
│     kubectl logs -n kube-system -l k8s-app=aws-node                        │
│     → IP assignment issues                                                   │
│                                                                             │
│  Root causes:                                                               │
│     • Wrong service name/FQDN                                              │
│     • Network policy blocking traffic                                       │
│     • Security group rules                                                  │
│     • VPC CNI not assigning IPs                                             │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Scenario 3: Node Not Joining Cluster

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  Interview Question: A new node is not joining the cluster. What do you do? │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Answer Structure:                                                          │
│  ──────────────────                                                         │
│                                                                             │
│  1. Check Node Status:                                                       │
│     kubectl get nodes                                                        │
│     → Is node listed? What state?                                           │
│                                                                             │
│  2. Check Node Logs (SSH into node):                                        │
│     journalctl -u kubelet                                                   │
│     /var/log/cloud-init-output.log                                          │
│     → Look for: "bootstrap failed", "certificate signed by unknown CA"      │
│                                                                             │
│  3. Common Issues:                                                           │
│     a) IAM Role Missing:                                                    │
│        → Node needs IAM role with AmazonEKSClusterPolicy                   │
│                                                                             │
│     b) Security Group Blocking:                                             │
│        → Node SG must allow outbound 443 to control plane                   │
│        → Control plane must reach node on 10250 (kubelet)                  │
│                                                                             │
│     c) API Server Reachability:                                             │
│        → Check if endpoint is accessible from node's VPC                   │
│        → Private endpoint vs public endpoint                               │
│                                                                             │
│     d) Bootstrap Script Issues:                                             │
│        → /etc/eks/bootstrap.sh may have wrong cluster name                 │
│        → Cluster certificate may be invalid                                │
│                                                                             │
│  4. Check ASG/Node Group:                                                   │
│     aws eks describe-nodegroup --cluster-name <cluster>                    │
│     → Check status, health issues                                           │
│                                                                             │
│  5. Resolution Steps:                                                        │
│     • Fix IAM role permissions                                              │
│     • Update security groups                                                │
│     • Check VPC connectivity (route tables, NAT)                            │
│     • Review cluster endpoint configuration                                 │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Scenario 4: High Latency Between Pods

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  Interview Question: Microservices have high latency. How do you diagnose?  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Answer Structure:                                                          │
│  ──────────────────                                                         │
│                                                                             │
│  1. Identify the Pattern:                                                   │
│     • Same AZ? Cross-AZ? Cross-region?                                      │
│     • Consistent or intermittent?                                           │
│                                                                             │
│  2. Check Pod Placement:                                                    │
│     kubectl get pods -o wide                                                │
│     → Are pods spread across AZs?                                           │
│     → Cross-AZ traffic has ~1-2ms latency                                   │
│                                                                             │
│  3. Optimize Pod Anti-Affinity:                                             │
│     affinity:                                                                │
│       podAntiAffinity:                                                      │
│         preferredDuringSchedulingIgnoredDuringExecution:                   │
│         - weight: 100                                                       │
│           podAffinityTerm:                                                  │
│             labelSelector:                                                  │
│               matchLabels:                                                  │
│                 app: my-service                                             │
│             topologyKey: kubernetes.io/hostname                            │
│                                                                             │
│  4. Check Node Utilization:                                                 │
│     kubectl top nodes                                                        │
│     kubectl describe node <node> | grep -A5 "Allocated resources"           │
│     → CPU/memory pressure can cause latency                                 │
│                                                                             │
│  5. Use Service Mesh (for production):                                      │
│     • Istio, Linkerd for observability                                      │
│     • Distributed tracing                                                   │
│     • mTLS overhead?                                                        │
│                                                                             │
│  6. Check VPC CNI Performance:                                              │
│     • CNI plugin adds overhead                                              │
│     • Consider Cilium or Calico for better performance                     │
│                                                                             │
│  7. Database/External Dependencies:                                         │
│     • Is latency in app or database?                                       │
│     • Use read replicas, connection pooling                                │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Scenario 5: EKS Upgrade Strategy

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  Interview Question: How do you plan an EKS cluster upgrade from 1.28→1.30? │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Answer Structure:                                                          │
│  ──────────────────                                                         │
│                                                                             │
│  1. Check Upgrade Path:                                                     │
│     • EKS supports N → N+1 (one minor version at a time)                   │
│     • Path: 1.28 → 1.29 → 1.30 (two upgrades)                              │
│     • Cannot skip versions                                                  │
│                                                                             │
│  2. Pre-Upgrade Checks:                                                     │
│     a) Check deprecated APIs:                                               │
│        kubent --k8s-version 1.29                                            │
│        → Identify deprecated APIs in manifests                              │
│                                                                             │
│     b) Check addon compatibility:                                           │
│        aws eks describe-addon-versions --addon-name vpc-cni                 │
│        → Ensure add-ons support new version                                 │
│                                                                             │
│     c) Check third-party tools:                                            │
│        • Helm charts compatibility                                         │
│        • CSI drivers                                                        │
│        • Service mesh (Istio, etc.)                                        │
│                                                                             │
│  3. Upgrade Sequence:                                                        │
│     Step 1: Update add-ons first (to compatible versions)                  │
│     Step 2: Upgrade control plane (AWS managed, ~15 min)                   │
│     Step 3: Upgrade node groups                                            │
│     Step 4: Verify workloads                                                │
│                                                                             │
│  4. Upgrade Commands:                                                        │
│     # Control plane                                                         │
│     aws eks update-cluster-version \                                        │
│       --name my-cluster --version 1.29                                      │
│                                                                             │
│     # Node groups (one at a time for HA)                                    │
│     aws eks update-nodegroup-version \                                      │
│       --cluster-name my-cluster \                                           │
│       --nodegroup-name my-nodes                                             │
│                                                                             │
│  5. Rollback Strategy:                                                       │
│     • EKS control plane cannot be rolled back                              │
│     • Node groups can use old launch template                              │
│     • Always backup before upgrade                                         │
│                                                                             │
│  6. Testing:                                                                │
│     • Upgrade staging first                                                 │
│     • Run integration tests                                                 │
│     • Monitor for 1-2 weeks                                                 │
│     • Then upgrade production                                               │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Scenario 6: Security Incident

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  Interview Question: A pod was compromised. What's your incident response? │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Answer Structure:                                                          │
│  ──────────────────                                                         │
│                                                                             │
│  1. Containment (Immediate):                                               │
│     a) Isolate the pod:                                                     │
│        kubectl delete pod <pod>  # If it respawns, scale down              │
│        kubectl scale deployment <deployment> --replicas=0                  │
│                                                                             │
│     b) Network isolation:                                                   │
│        kubectl patch networkpolicy default-deny -n <namespace>             │
│        → Apply deny-all policy                                              │
│                                                                             │
│     c) Revoke IAM credentials:                                              │
│        • If IRSA used: Check CloudTrail for actions                        │
│        • Rotate credentials if static credentials found                    │
│                                                                             │
│  2. Investigation:                                                           │
│     a) Collect evidence:                                                    │
│        kubectl logs <pod> --previous                                        │
│        kubectl describe pod <pod>                                          │
│        kubectl get events --sort-by='.lastTimestamp'                        │
│                                                                             │
│     b) Check for lateral movement:                                         │
│        kubectl auth can-i --list --as=system:anonymous                     │
│        → Check what compromised pod can access                              │
│                                                                             │
│     c) CloudTrail analysis:                                                 │
│        → What AWS APIs were called?                                        │
│        → From which IP? When?                                               │
│                                                                             │
│  3. Eradication:                                                            │
│     a) Remove malicious artifacts:                                         │
│        • Delete compromised pod/deployment                                  │
│        • Remove any malicious ConfigMaps/Secrets                           │
│                                                                             │
│     b) Patch vulnerabilities:                                              │
│        • Update container image                                             │
│        • Fix application vulnerabilities                                    │
│                                                                             │
│  4. Recovery:                                                               │
│     a) Deploy clean version:                                                │
│        kubectl apply -f clean-deployment.yaml                              │
│                                                                             │
│     b) Verify security:                                                    │
│        • Check pod security context                                         │
│        • Verify network policies                                           │
│        • Review RBAC permissions                                            │
│                                                                             │
│  5. Post-Incident:                                                          │
│     a) Documentation:                                                        │
│        • Incident report                                                    │
│        • Timeline of actions                                                │
│        • Root cause analysis                                                │
│                                                                             │
│     b) Improvements:                                                        │
│        • Add runtime security (Falco, Sysdig)                              │
│        • Implement pod security policies                                   │
│        • Enable audit logging                                               │
│        • Add network policies                                               │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 12. Troubleshooting Guide

### Common Issues and Solutions

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Troubleshooting Quick Reference                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Issue: Pod Stuck in Pending                                               │
│  ─────────────────────────────────                                          │
│  kubectl describe pod <pod-name>                                            │
│  → Check Events section                                                     │
│  → Common causes:                                                           │
│    • Insufficient CPU/memory → Scale nodes                                 │
│    • PVC not bound → Check storage class                                    │
│    • Node selector mismatch → Check labels                                 │
│    • Taints/tolerations → Node may be tainted                              │
│                                                                             │
│  Issue: Pod Stuck in CrashLoopBackOff                                      │
│  ──────────────────────────────────────                                     │
│  kubectl logs <pod-name> --previous                                         │
│  kubectl describe pod <pod-name>                                            │
│  → Common causes:                                                           │
│    • Application error → Check logs                                         │
│    • Missing config/secrets → Check ConfigMaps, Secrets                    │
│    • Health check failing → Adjust probes                                   │
│    • Resource limits → Increase memory/CPU                                  │
│                                                                             │
│  Issue: Node Not Ready                                                     │
│  ──────────────────────────                                                 │
│  kubectl describe node <node-name>                                          │
│  → Check Conditions section                                                 │
│  → Common causes:                                                           │
│    • Disk pressure → Clean up images/volumes                               │
│    • Memory pressure → Evict pods                                           │
│    • Network unavailable → Check VPC/SG                                     │
│    • Kubelet not running → SSH and restart                                 │
│                                                                             │
│  Issue: Service Not Accessible                                              │
│  ─────────────────────────────                                              │
│  kubectl get endpoints <service-name>                                       │
│  → If empty: selector doesn't match pods                                   │
│  → Check pod labels match service selector                                  │
│  → Check pod is running and ready                                           │
│                                                                             │
│  Issue: IRSA Not Working                                                    │
│  ──────────────────────────                                                 │
│  kubectl logs <pod>                                                          │
│  → Look for: "AccessDenied", "NoCredentialProviders"                       │
│  → Check:                                                                   │
│    • Service account annotation                                             │
│    • IAM role trust policy (OIDC)                                          │
│    • Policy permissions                                                     │
│                                                                             │
│  Issue: Cluster Autoscaler Not Scaling                                     │
│  ─────────────────────────────────────                                      │
│  kubectl logs -n kube-system deployment/cluster-autoscaler                 │
│  → Check for:                                                               │
│    • IAM permission errors                                                  │
│    • Max nodes reached                                                      │
│    • Tags missing on ASG                                                   │
│    • Instance type unavailable                                              │
│                                                                             │
│  Issue: DNS Resolution Failed                                               │
│  ─────────────────────────────                                              │
│  kubectl run test --image=busybox --rm -it -- nslookup kubernetes          │
│  → If fails:                                                                │
│    • Check CoreDNS pods running                                             │
│    • Check CoreDNS service exists                                           │
│    • Check /etc/resolv.conf in pods                                         │
│    • Check VPC DNS resolution                                               │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Useful Commands

```bash
# Cluster Info
kubectl cluster-info
kubectl get nodes -o wide
kubectl get namespaces

# Workload Debugging
kubectl get pods -A -o wide
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace> --previous
kubectl exec -it <pod-name> -n <namespace> -- /bin/sh

# Node Debugging
kubectl describe node <node-name>
kubectl get node <node-name> -o yaml
kubectl cordon <node-name>      # Mark unschedulable
kubectl drain <node-name>       # Evict pods
kubectl uncordon <node-name>    # Mark schedulable

# Networking
kubectl get svc -A
kubectl get endpoints <service-name>
kubectl run test --image=busybox --rm -it -- nslookup <service-name>
kubectl run test --image=busybox --rm -it -- wget -qO- http://<service>:port

# RBAC
kubectl auth can-i --list
kubectl auth can-i <verb> <resource> --as=system:anonymous
kubectl get rolebindings,clusterrolebindings -A

# Resource Usage
kubectl top nodes
kubectl top pods -A
kubectl describe node <node> | grep -A10 "Allocated resources"

# Events
kubectl get events --sort-by='.lastTimestamp' -A
kubectl get events --field-selector reason=Failed

# Add-ons
kubectl get pods -n kube-system
kubectl logs -n kube-system deployment/coredns
kubectl logs -n kube-system daemonset/aws-node
kubectl logs -n kube-system daemonset/kube-proxy

# Cleanup
kubectl delete pod <pod> --force --grace-period=0
kubectl delete all --all -n <namespace>
```

---

## Quick Reference Card

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          EKS Quick Reference                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Components Created:                                                        │
│  ─────────────────────                                                       │
│  ✓ VPC with 3 AZs, public/private subnets                                   │
│  ✓ NAT Gateway (single)                                                     │
│  ✓ EKS Control Plane (AWS managed)                                         │
│  ✓ Managed Node Group (t3.medium)                                          │
│  ✓ OIDC Provider (for IRSA)                                                │
│  ✓ EKS Add-ons (coredns, kube-proxy, vpc-cni)                              │
│  ✓ Cluster Autoscaler IRSA role                                            │
│                                                                             │
│  Key Files:                                                                 │
│  ─────────────                                                               │
│  main.tf               → VPC + EKS + Add-ons                                │
│  variables.tf          → Input configuration                                │
│  cluster-autoscaler.tf → IRSA for autoscaler                               │
│  versions.tf           → Provider versions                                  │
│  outputs.tf            → Cluster info                                       │
│                                                                             │
│  Useful Outputs:                                                            │
│  ──────────────────                                                          │
│  terraform output cluster_name                                              │
│  terraform output cluster_endpoint                                          │
│  terraform output cluster_autoscaler_role_arn                               │
│                                                                             │
│  Connect to Cluster:                                                        │
│  ──────────────────                                                          │
│  aws eks update-kubeconfig --region <region> --name <cluster>              │
│  kubectl get nodes                                                          │
│                                                                             │
│  Deploy Autoscaler:                                                          │
│  ──────────────────                                                          │
│  terraform output -raw cluster_autoscaler_manifest | kubectl apply -f -     │
│                                                                             │
│  Cost Management:                                                           │
│  ──────────────────                                                          │
│  terraform destroy  # Stop all costs                                        │
│  terraform apply    # Recreate (~15-20 min)                                 │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Summary

This project implements a production-ready EKS cluster with:

| Component | Implementation | Purpose |
|-----------|---------------|---------|
| **VPC** | 3 AZs, public/private subnets | Network isolation |
| **NAT Gateway** | Single gateway | Outbound internet for private subnets |
| **EKS** | Managed control plane | Kubernetes orchestration |
| **Node Group** | Managed, t3.medium | Worker nodes |
| **Add-ons** | VPC CNI, CoreDNS, kube-proxy | Core cluster functionality |
| **IRSA** | OIDC provider + IAM roles | Pod-level AWS permissions |
| **Cluster Autoscaler** | IRSA + Kubernetes manifest | Auto-scaling nodes |
| **Security** | CIDR restrictions, private subnets | Defense in depth |

For further learning:
- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [EKS Best Practices Guide](https://aws.github.io/aws-eks-best-practices/)
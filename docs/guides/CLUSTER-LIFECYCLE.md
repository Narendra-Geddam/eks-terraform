# EKS Cluster Lifecycle Guide

Complete guide for **deploying** and **destroying** your EKS infrastructure.

---

## 📋 Table of Contents

1. [Quick Start - Deploy](#-quick-start---deploy)
2. [Quick Start - Destroy](#-quick-start---destroy)
3. [Deployment in Detail](#deployment-in-detail)
4. [Destruction in Detail](#destruction-in-detail)
5. [Troubleshooting](#troubleshooting)
6. [Cost Management](#cost-management)

---

# ✅ Quick Start - Deploy

### Automated Deployment (Recommended)

#### PowerShell (Windows)
```powershell
.\start-cluster.ps1
```

#### Bash (Linux/macOS)
```bash
chmod +x start-cluster.sh
./start-cluster.sh
```

### What Gets Created

| Component | Details |
|-----------|---------|
| **VPC** | 10.20.0.0/16 with 3 public and 3 private subnets across 3 AZs |
| **EKS Cluster** | Kubernetes 1.35 (configurable) |
| **Node Group** | 2x t3.medium instances (min 1, max 3, configurable) |
| **ALB Controller** | v3.1.0 via Helm with IRSA |
| **Cluster Autoscaler** | For automatic node scaling |
| **IAM Roles** | OIDC-based IRSA for fine-grained permissions |
| **Security Groups** | Properly configured for cluster and node communication |

⏳ **Expected Time**: 15-25 minutes

---

# ❌ Quick Start - Destroy

### Automated Destruction (Recommended)

#### PowerShell (Windows)
```powershell
.\stop-cluster.ps1
```

#### Bash (Linux/macOS)
```bash
chmod +x stop-cluster.sh
./stop-cluster.sh
```

### What Gets Destroyed

| Phase | Resources |
|-------|-----------|
| **Phase 1** | Helm releases, Ingress objects, LoadBalancer services, Deployments |
| **Phase 2** | EKS cluster, Node groups, VPC, IAM roles, Security groups, NAT gateways |
| **Phase 3** | Terraform state files (only if destroy succeeds) |

---

# 🚀 Deployment in Detail

## Pre-Deployment Setup

### 1. Copy Configuration Template

```bash
cp terraform.tfvars.example terraform.tfvars
```

### 2. Edit `terraform.tfvars`

```hcl
aws_region         = "eu-north-1"      # AWS region
project_name       = "my-platform"     # Project name for tags
environment        = "test"            # Environment label
cluster_name       = "my-eks-cluster"  # Cluster name
kubernetes_version = "1.35"            # Kubernetes version
vpc_cidr           = "10.20.0.0/16"    # VPC CIDR block

node_instance_types = ["t3.medium"]    # Instance type
node_desired_size   = 2                # Initial nodes
node_min_size       = 1                # Minimum nodes
node_max_size       = 3                # Maximum nodes
```

### 3. Verify AWS Credentials

```bash
aws sts get-caller-identity
aws configure  # If not configured
```

---

## Manual Deployment Steps

### Step 1: Initialize Terraform

```bash
# Download providers and modules
terraform init

# Validate configuration
terraform validate
```

### Step 2: Review Plan

```bash
# Generate deployment plan
terraform plan -out=tfplan

# Review output - shows all resources to be created
cat tfplan
```

### Step 3: Deploy Infrastructure

```bash
# Apply the plan (creates all resources)
terraform apply tfplan

# Or without pre-generated plan
terraform apply --auto-approve
```

### Step 4: Configure kubectl Access

```bash
# Update kubeconfig with new cluster
aws eks update-kubeconfig --region eu-north-1 --name my-eks-cluster

# Verify access
kubectl get nodes
```

### Step 5: Verify Deployment

```bash
# Check cluster version
kubectl cluster-info

# List all nodes
kubectl get nodes -o wide

# Check ALB controller
kubectl -n kube-system get deployment aws-load-balancer-controller

# View ALB controller logs
kubectl -n kube-system logs -l app.kubernetes.io/name=aws-load-balancer-controller
```

---

## Post-Deployment Tasks

### 1. Test Cluster Access

```bash
# Get cluster info
kubectl cluster-info

# List all resources
kubectl get all -A

# Check system pods
kubectl get pods -n kube-system
```

### 2. Test ALB Controller

Deploy a sample application:

```bash
# Create nginx deployment
kubectl create deployment nginx --image=nginx:latest

# Expose via LoadBalancer service
kubectl expose deployment nginx --port=80 --type=LoadBalancer

# Wait for ALB to be created
kubectl get svc

# Access the application
curl http://<LoadBalancer-IP>
```

### 3. Monitor Resources

```bash
# Watch pod creation
kubectl get pods -w

# Monitor node resources
kubectl top nodes

# Check events
kubectl get events -A

# View cluster autoscaler logs
kubectl -n kube-system logs -l app.kubernetes.io/name=aws-cluster-autoscaler
```

---

# 🗑️ Destruction in Detail

## Manual Destruction Steps

If you prefer to destroy manually or need to debug:

### Step 1: Delete Helm Releases

```bash
# List all helm releases
helm list -A

# Delete ALB Controller
helm uninstall aws-load-balancer-controller -n kube-system

# Delete Cluster Autoscaler if present
helm uninstall cluster-autoscaler -n kube-system

# Delete any other custom releases
helm uninstall <release-name> -n <namespace>
```

### Step 2: Delete Kubernetes Resources

```bash
# Delete Ingress resources
kubectl delete ingress --all --all-namespaces

# Delete LoadBalancer services (IMPORTANT - triggers ALB deletion)
kubectl delete svc --all --all-namespaces

# Wait for ALBs to be deleted
sleep 30

# Delete deployments
kubectl delete deployment --all --all-namespaces
kubectl delete daemonset --all --all-namespaces
kubectl delete statefulset --all --all-namespaces

# Delete custom namespaces
kubectl delete ns <namespace-name>
```

### Step 3: Destroy Infrastructure with Terraform

```bash
# Preview what will be destroyed
terraform plan -destroy

# Destroy all resources
terraform destroy --auto-approve

# Or with confirmation
terraform destroy
```

### Step 4: Clean Up State Files

```bash
# Remove Terraform directories and files
rm -rf .terraform/
rm terraform.tfstate
rm terraform.tfstate.backup
rm terraform.tfstate.*.backup
rm .terraform.tfstate.lock.info
```

---

## Verification After Destruction

### Verify Terraform State is Clean
```bash
terraform state list
# Should return nothing or "(empty)"
```

### Verify AWS Resources Deleted

Check AWS Console for:

1. **EKS Dashboard**: No clusters listed
   - https://console.aws.amazon.com/eks/home

2. **EC2 Instances**: No running instances
   - https://console.aws.amazon.com/ec2/home

3. **Load Balancers**: No ALBs/NLBs
   - https://console.aws.amazon.com/ec2/v2/home#LoadBalancers

4. **VPC**: All custom VPCs deleted
   - https://console.aws.amazon.com/vpc/home

5. **IAM Roles**: ALB controller and cluster roles deleted
   - https://console.aws.amazon.com/iam/home#/roles

---

# 🔧 Troubleshooting

## Deployment Issues

### Issue 1: "AWS credentials not configured"

**Problem**: Terraform can't authenticate to AWS

**Solution**:
```bash
# Configure AWS credentials
aws configure

# Or use environment variables
export AWS_ACCESS_KEY_ID=xxx
export AWS_SECRET_ACCESS_KEY=xxx
export AWS_REGION=eu-north-1

# Verify configuration
aws sts get-caller-identity
```

### Issue 2: "Timeout waiting for EKS cluster creation"

**Problem**: Cluster creation taking >20 minutes

**Solution**:
- This is normal for first deployment
- Monitor in AWS Console: EKS → Clusters
- Check CloudFormation events for errors

```bash
# Check CloudFormation stack status
aws cloudformation describe-stacks --stack-name eksctl-my-eks-cluster-cluster
```

### Issue 3: "Nodes not joining cluster"

**Problem**: Nodes show "NotReady" status

**Solution**:
```bash
# Check node status
kubectl get nodes

# Describe problematic node
kubectl describe node <node-name>

# Check node logs/events
aws ec2 describe-instances --filters Name=tag:Name,Values=my-eks-cluster-node
```

### Issue 4: "ALB controller pods not running"

**Problem**: ALB controller deployment shows 0/2 ready

**Solution**:
```bash
# Check pod status
kubectl -n kube-system get pods -l app.kubernetes.io/name=aws-load-balancer-controller

# Describe pod for errors
kubectl -n kube-system describe pod aws-load-balancer-controller-XXX

# Check pod logs
kubectl -n kube-system logs aws-load-balancer-controller-XXX

# Verify service account
kubectl -n kube-system get sa aws-load-balancer-controller

# Verify IAM role attachment
kubectl -n kube-system get sa aws-load-balancer-controller -o yaml
```

### Issue 5: "Permission denied" when running scripts

**Problem**: `./start-cluster.sh: Permission denied`

**Solution** (Linux/macOS):
```bash
chmod +x start-cluster.sh
./start-cluster.sh
```

---

## Destruction Issues

### Issue 1: "Network vpc-xxx has some mapped public address(es)"

**Problem**: ALBs/NLBs still exist when destroying VPC

**Solution**: 
```bash
# Ensure all LoadBalancer services are deleted
kubectl delete svc --all --all-namespaces
sleep 30
terraform destroy --auto-approve
```

### Issue 2: "Error deleting IAM Role - role has attached policies"

**Problem**: Terraform tries to delete role before detaching policies

**Solution**: Wait a few moments and retry:
```bash
terraform destroy --auto-approve
```
Terraform usually handles this automatically on retry.

### Issue 3: "The requested configuration exceeds the maximum size allowed"

**Problem**: Large Terraform state file

**Solution**: Clean up and retry:
```bash
terraform destroy --auto-approve
```

### Issue 4: Instance termination timing out

**Problem**: EC2 instances take time to shut down

**Solution**: This is normal; terraform automatically retries:
```bash
terraform destroy --auto-approve
```

### Issue 5: DynamoDB table locked during destroy

**Problem**: State lock is held

**Solution**: Force unlock if truly stuck:
```bash
terraform force-unlock <lock-id>
terraform destroy --auto-approve
```

---

## Emergency Cleanup

If Terraform destroy fails repeatedly:

### Option 1: Destroy via AWS Console
1. Delete ALBs/NLBs first
2. Delete security groups manually
3. Delete EKS cluster
4. Delete VPC (this will delete subnets, etc.)
5. Delete IAM roles via IAM console

### Option 2: Force Delete Terraform State
⚠️ **Only if automated destroy completely fails**

```bash
# Remove state file to forget resources
rm -f terraform.tfstate*
rm -rf .terraform/

# WARNING: Resources might remain in AWS and continue costing money
# Check AWS Console and delete manually
```

---

# 💰 Cost Management

## Monthly Cost Breakdown

| Component | Monthly Cost | Status |
|-----------|-------------|--------|
| EKS Cluster | ~$73 | ✅ Running |
| NAT Gateway | ~$32 | ✅ Running |
| EC2 Instances (2x t3.medium) | ~$30 | ✅ Running |
| **Total** | **~$135** | **✅ Running** |

## Stop Cost

After destroying the cluster:
- **Total Monthly Cost**: $0 (100% savings)
- **State backend (optional)**: ~$2/month (S3 + DynamoDB)

---

## Redeploy / Recreate

To recreate your cluster later:

```bash
terraform init
terraform apply --auto-approve
```

Or use the start script:
```powershell
# Windows
.\start-cluster.ps1
```

```bash
# Linux/macOS
./start-cluster.sh
```

---

## State Backend (S3 + DynamoDB)

The S3 state bucket and DynamoDB lock table **persist after destroy**. They only contain your configuration, not running infrastructure.

### To keep state backend:
No action needed - leave them running (costs ~$2/month)

### To fully delete everything including state backend:
```bash
# Delete S3 bucket and DynamoDB table via AWS Console or:
aws s3 rb s3://eks-terraform-state-eu-north-1 --force
aws dynamodb delete-table --table-name eks-terraform-locks --region eu-north-1
```

---

## Quick Reference

| Action | Command |
|--------|---------|
| **Deploy** | `.\start-cluster.ps1` or `./start-cluster.sh` |
| **Destroy** | `.\stop-cluster.ps1` or `./stop-cluster.sh` |
| **Get nodes** | `kubectl get nodes` |
| **Check ALB** | `kubectl -n kube-system get deployment aws-load-balancer-controller` |
| **View logs** | `kubectl -n kube-system logs -l app.kubernetes.io/name=aws-load-balancer-controller` |
| **Check AWS** | `aws eks describe-cluster --name my-eks-cluster` |

---

**Created by**: DevOps Automation
**Last Updated**: March 2026

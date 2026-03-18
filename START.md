# Infrastructure Startup Guide

This guide explains how to deploy your complete EKS cluster with all integrated components.

## Quick Start

### Option 1: Automated Deployment (Recommended)

#### PowerShell (Windows)
```powershell
.\start-cluster.ps1
```

#### Bash (Linux/macOS)
```bash
chmod +x start-cluster.sh
./start-cluster.sh
```

## What Gets Created

### Phase 1: Pre-flight Checks
- ✅ **Prerequisites**: Terraform, AWS CLI, kubectl, Helm
- ✅ **AWS Credentials**: Verify authentication
- ✅ **Configuration**: Create/load `terraform.tfvars`

### Phase 2: Terraform Initialization
- ✅ **Provider Setup**: Initialize AWS, Kubernetes, Helm providers
- ✅ **Dependency Resolution**: Download required modules and plugins
- ✅ **Validation**: Verify Terraform configuration syntax

### Phase 3: Planning
- ✅ **Resource Plan**: Preview all resources to be created
- ✅ **User Confirmation**: Review plan before proceeding

### Phase 4: Infrastructure Deployment
- ✅ **VPC**: 10.20.0.0/16 with 3 public and 3 private subnets across 3 AZs
- ✅ **EKS Cluster**: Kubernetes 1.35 (configurable)
- ✅ **Node Group**: 2x t3.medium instances (min 1, max 3, configurable)
- ✅ **ALB Controller**: v3.1.0 via Helm with IRSA
- ✅ **Cluster Autoscaler**: For automatic node scaling
- ✅ **IAM Roles**: OIDC-based IRSA for fine-grained permissions
- ✅ **Security Groups**: Properly configured for cluster and node communication

### Phase 5: Post-Deployment
- ✅ **Kubeconfig Update**: Automatic kubectl access configuration
- ✅ **Cluster Verification**: Wait for cluster readiness
- ✅ **Node Validation**: Confirm all nodes are running
- ✅ **ALB Controller Check**: Verify controller pods are deployed

---

## Configuration

### Pre-Deployment Setup

1. **Copy configuration template**:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. **Edit `terraform.tfvars`** with your settings:
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

3. **Verify AWS credentials**:
   ```bash
   aws sts get-caller-identity
   aws configure  # If not configured
   ```

---

## Manual Deployment Steps

If you prefer to deploy manually or need to debug:

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
cat tfplan  # View JSON plan
```

### Step 3: Deploy Infrastructure

```bash
# Apply the plan (creates all resources)
terraform apply tfplan

# Or without pre-generated plan
terraform apply --auto-approve
```

**⏳ Expected Time**: 15-25 minutes

Monitor progress:
- VPC creation: ~2 minutes
- EKS cluster: ~10-15 minutes
- Node group: ~5-10 minutes
- ALB controller deployment: ~2 minutes

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

## Common Issues & Solutions

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

### 4. Set Up Monitoring (Optional)

For production use, consider adding:
- Prometheus for metrics
- Grafana for dashboards
- Loki for logging
- ELK stack for centralized logs

See official documentation for setup instructions.

---

## Cost Estimation

| Component | Monthly Cost |
|-----------|-------------|
| EKS Control Plane | ~$73 |
| NAT Gateway (1) | ~$32 |
| EC2 Instances (2x t3.medium) | ~$30 |
| Data Transfer | ~$5-15 |
| **Total** | **~$140-160** |

**Free tier**: If within AWS free tier limits, costs may be lower.

---

## Verification Checklist

After deployment, verify:

- [ ] EKS cluster visible in AWS Console
- [ ] All nodes in "Ready" state
- [ ] ALB controller pods running (2 replicas)
- [ ] kubectl commands work without errors
- [ ] Can list nodes: `kubectl get nodes`
- [ ] Can list pods: `kubectl get pods -A`
- [ ] ALB controller logs show no errors
- [ ] OIDC provider created for IRSA
- [ ] IAM roles properly attached
- [ ] VPC subnets have correct tags

```bash
# Quick verification script
echo "=== Cluster Status ==="
kubectl cluster-info
echo ""
echo "=== Nodes ==="
kubectl get nodes
echo ""
echo "=== System Pods ==="
kubectl -n kube-system get pods
echo ""
echo "=== ALB Controller ==="
kubectl -n kube-system get deployment aws-load-balancer-controller
```

---

## Accessing Cluster Remotely

If accessing from another machine:

```bash
# Get kubeconfig from S3 or local copy
# Transfer terraform.tfvars and .terraform/ directory

# Then run on remote machine
terraform init
aws eks update-kubeconfig --region eu-north-1 --name my-eks-cluster
kubectl get nodes
```

---

## Scaling Configuration

After deployment, adjust cluster size:

1. **Edit terraform.tfvars**:
   ```hcl
   node_desired_size = 3    # Increase from 2 to 3
   ```

2. **Apply changes**:
   ```bash
   terraform apply
   ```

3. **Cluster Autoscaler** will automatically handle scaling based on pod resource requests.

---

## Upgrading Kubernetes

To upgrade cluster version:

1. **Edit terraform.tfvars**:
   ```hcl
   kubernetes_version = "1.36"  # Change version
   ```

2. **Plan and apply**:
   ```bash
   terraform plan
   terraform apply
   ```

3. **Monitor upgrade**:
   ```bash
   kubectl get nodes -w
   ```

---

## Troubleshooting

### Enable Debug Logging

```bash
# Terraform debug mode
export TF_LOG=DEBUG
terraform apply

# AWS CLI debug
aws eks describe-cluster --name my-eks-cluster --debug

# kubectl verbose
kubectl get nodes -v=8
```

### Check CloudFormation

```bash
# List stacks
aws cloudformation list-stacks

# Describe specific stack
aws cloudformation describe-stack-resources --stack-name eksctl-my-eks-cluster-cluster
```

### View Events

```bash
# Kubernetes events
kubectl get events -A

# Sort by time
kubectl get events -A --sort-by='.lastTimestamp'
```

---

## Next Steps

1. **Deploy applications**: See examples in `alb.md`
2. **Set up monitoring**: Configure Prometheus/Grafana/Loki
3. **Enable log aggregation**: CloudWatch Logs or centralized logging
4. **Configure RBAC**: Fine-grained access control
5. **Set up CI/CD**: Integrate with GitOps tools
6. **Read documentation**: 
   - [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
   - [Kubernetes Official Docs](https://kubernetes.io/docs/)
   - [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest)

---

## Cleanup

When ready to destroy infrastructure:

```powershell
# PowerShell
.\stop-cluster.ps1
```

```bash
# Bash
./stop-cluster.sh
```

This will safely remove all resources and save costs.

See [DESTROY.md](DESTROY.md) for detailed cleanup information.

---

## Support & Resources

- **Terraform Documentation**: https://www.terraform.io/docs
- **AWS EKS Guide**: https://docs.aws.amazon.com/eks/
- **Kubernetes Docs**: https://kubernetes.io/docs/
- **GitHub Issues**: https://github.com/hashicorp/terraform-provider-aws/issues
- **AWS Support**: https://console.aws.amazon.com/support/


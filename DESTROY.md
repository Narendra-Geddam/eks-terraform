# Infrastructure Destruction Guide

This guide explains how to safely destroy your EKS cluster and all associated resources while avoiding common errors.

## Quick Start

### Option 1: Automated Destruction (Recommended)

#### PowerShell (Windows)
```powershell
.\stop-cluster.ps1
```

#### Bash (Linux/macOS)
```bash
chmod +x stop-cluster.sh
./stop-cluster.sh
```

## What Gets Destroyed

### Phase 1: Kubernetes Resource Cleanup
- ✅ **Helm Releases**: ALB Controller, Cluster Autoscaler, Karpenter, monitoring
- ✅ **Ingress Resources**: All ingress objects across all namespaces
- ✅ **LoadBalancer Services**: Triggers cleanup of AWS Application Load Balancers (ALBs)
- ✅ **Deployments**: All deployments, DaemonSets, StatefulSets
- ✅ **Custom Namespaces**: Removes all non-system namespaces
- ✅ **30-second wait**: Allow AWS ALBs time to deprovision before destroying infrastructure

### Phase 2: Infrastructure Teardown
- ✅ **EKS Cluster**: Kubernetes cluster
- ✅ **Node Groups**: Managed EC2 instances
- ✅ **VPC**: Virtual Private Cloud and all subnets
- ✅ **IAM Roles**: IRSA roles, ALB controller role, cluster autoscaler role
- ✅ **Security Groups**: All security groups
- ✅ **Route Tables & NAT Gateways**: Networking infrastructure
- ✅ **OIDC Provider**: IAM OpenID Connect provider for IRSA

### Phase 3: State File Cleanup
- ✅ **Terraform Directory**: `.terraform/` folder
- ✅ **State Files**: `terraform.tfstate` and backups
- ✅ **Lock Files**: `.terraform.tfstate.lock.info`

---

## Manual Destruction Steps

If you prefer to destroy resources manually or need to debug issues:

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

## Common Issues & Solutions

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
   - https://console.aws.amazon.com/ec2/home?region=eu-north-1#Instances

3. **Load Balancers**: No ALBs/NLBs
   - https://console.aws.amazon.com/ec2/v2/home?region=eu-north-1#LoadBalancers

4. **VPC**: All custom VPCs deleted
   - https://console.aws.amazon.com/vpc/home

5. **IAM Roles**: ALB controller and cluster roles deleted
   - https://console.aws.amazon.com/iam/home#/roles

6. **S3 Bucket**: State bucket still exists but should be empty
   - https://s3.console.aws.amazon.com/s3/home

---

## Cost Impact

| Component | Monthly Cost | Status |
|-----------|-------------|--------|
| EKS Cluster | ~$73 | ❌ Stopped |
| NAT Gateway | ~$32 | ❌ Stopped |
| EC2 Instances (2x t3.medium) | ~$30 | ❌ Stopped |
| **Total** | **~$135** | **❌ Stopped** |

**Savings**: 100% of cluster costs

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

## Troubleshooting

### Check Kubernetes Cluster Access
```bash
kubectl get nodes
```

If it fails, ensure kubeconfig is updated:
```bash
aws eks update-kubeconfig --region eu-north-1 --name my-eks-cluster
```

### Check ALB Controller Status Before Destroy
```bash
kubectl -n kube-system get deployment aws-load-balancer-controller
kubectl -n kube-system get pods -l app.kubernetes.io/name=aws-load-balancer-controller
kubectl -n kube-system logs -l app.kubernetes.io/name=aws-load-balancer-controller --tail=50
```

### Check Helm Status
```bash
helm list -n kube-system
helm status aws-load-balancer-controller -n kube-system
helm get values aws-load-balancer-controller -n kube-system
```

---

## Script Customization

Edit `stop-cluster.ps1` or `stop-cluster.sh` to customize which resources are deleted.

Add helm releases to cleanup:
```powershell
# stop-cluster.ps1
$helmReleases = @(
    "aws-load-balancer-controller",
    "karpenter",
    "cluster-autoscaler",
    "my-custom-release"  # Add here
)
```

---

## Support

For issues with Terraform destruction, check:
- [Terraform AWS Provider Issues](https://github.com/hashicorp/terraform-provider-aws/issues)
- [EKS Troubleshooting Guide](https://docs.aws.amazon.com/eks/latest/userguide/troubleshooting.html)
- AWS Support Console for account-level issues

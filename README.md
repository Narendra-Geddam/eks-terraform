# EKS on AWS with Terraform

This folder provisions a complete Amazon EKS environment in your AWS account using Terraform:

- VPC across 3 AZs
- Public and private subnets
- NAT gateway (single)
- EKS control plane
- EKS managed node group
- IAM OIDC provider (IRSA support)
- EKS managed add-ons (coredns, kube-proxy, vpc-cni)
- Cluster Autoscaler IRSA role (deploy manifest after cluster creation)

## What I built

- [versions.tf](versions.tf): Terraform and provider version constraints
- [provider.tf](provider.tf): AWS provider + account/AZ data sources
- [variables.tf](variables.tf): All configurable inputs
- [main.tf](main.tf): VPC + EKS module with managed add-ons
- [outputs.tf](outputs.tf): Cluster endpoint, VPC ID, subnet IDs, add-on status
- [cluster-autoscaler.tf](cluster-autoscaler.tf): IAM role for Cluster Autoscaler (IRSA)
- [terraform.tfvars.example](terraform.tfvars.example): Example values to copy
- [start-cluster.ps1](start-cluster.ps1): Quick start script (PowerShell)
- [stop-cluster.ps1](stop-cluster.ps1): Quick destroy script (PowerShell)
- [backend.md](backend.md): Remote state learning guide
- [eks.md](eks.md): **Complete EKS guide** (architecture, components, interview scenarios)

**Reference files** (not active, for learning):
- [bootstrap-state-storage.tf](bootstrap-state-storage.tf): S3 + DynamoDB bootstrap
- [modules/state-storage/](modules/state-storage/): State infrastructure module

## Prerequisites

- Terraform `>= 1.6.0`
- AWS CLI configured with credentials that can create VPC, IAM, EKS, EC2, and related resources
- Optional: `kubectl` to interact with the cluster (use system-wide install, not repo binary)

## Remote State Backend

> **Note**: This project uses **local state** for simplicity (suitable for learning).
> See [`backend.md`](backend.md) to learn about remote state for team/production use.

State is stored locally in `terraform.tfstate` (gitignored).

### Why Local State for This Project?

| Aspect | Local State | Remote State |
|--------|-------------|--------------|
| Complexity | Simple | Requires S3 + DynamoDB setup |
| Cost | Free | ~$1/month for S3 |
| Team use | Single developer | Multiple developers |
| Best for | Learning, personal projects | Production, teams |

### Files for Remote State (Reference Only)

The following files are included for **learning purposes**. They are not active:

| File | Purpose |
|------|---------|
| `bootstrap-state-storage.tf` | Creates S3 + DynamoDB (run once) |
| `modules/state-storage/` | State infrastructure module |
| `versions.tf` (commented) | Backend configuration |

To enable remote state in the future, see [`backend.md`](backend.md) for step-by-step instructions.

## Quick start (PowerShell)

### Step 1: Bootstrap Remote State (Optional - For Learning)

> **Skip this step for local state.** This is included for learning purposes only.

If you want to use remote state for team collaboration, see [`backend.md`](backend.md) for instructions.

### Step 2: Deploy EKS Cluster

1. Move into the project:

```powershell
cd c:\Users\don81\OneDrive\Desktop\DevOps\eks\terraform-eks
```

2. Copy example variables:

```powershell
Copy-Item terraform.tfvars.example terraform.tfvars
```

3. Edit `terraform.tfvars` for your account preferences (cluster name, region, node size, etc.).

4. Initialize Terraform:

```powershell
terraform init
```

5. Review plan:

```powershell
terraform plan -out plan.out
```

6. Apply:

```powershell
terraform apply plan.out
```

Provisioning usually takes around 15-25 minutes.

## Connect to cluster

After apply completes:

```powershell
aws eks update-kubeconfig --region <your-region> --name <your-cluster-name>
kubectl get nodes
```

Example:

```powershell
aws eks update-kubeconfig --region eu-north-1 --name my-eks-cluster
kubectl get nodes
```

## Security: API Endpoint Access

By default, the EKS API endpoint is publicly accessible from any IP (`0.0.0.0/0`). For production, restrict access to specific CIDRs:

```hcl
# In terraform.tfvars
cluster_endpoint_public_access_cidrs = [
  "203.0.113.0/24",  # Office IP range
  "198.51.100.0/24"  # VPN IP range
]
```

To find your current IP:
```powershell
(Invoke-WebRequest -Uri "https://checkip.amazonaws.com").Content
```

## Cluster Autoscaler

The Cluster Autoscaler automatically adjusts node count based on workload demand.

### What's Created
- IAM policy for ASG management
- IAM role with IRSA (IAM Roles for Service Accounts)
- Kubernetes manifest (ServiceAccount, ClusterRole, Deployment)

### Deploy After Cluster Creation

```powershell
# Get cluster outputs
terraform output cluster_autoscaler_role_arn

# Apply the Kubernetes manifest
terraform output -raw cluster_autoscaler_manifest | kubectl apply -f -

# Verify it's running
kubectl get pods -n kube-system -l app=cluster-autoscaler
```

### How It Works
- Watches for unschedulable pods → adds nodes
- Scales down when nodes are underutilized
- Uses tags on node groups: `k8s.io/cluster-autoscaler/enabled` and `k8s.io/cluster-autoscaler/<cluster-name>`

## First-time access checklist (EKS managed)

Use this if this is your first EKS cluster and you are not sure how to connect.

1. Confirm your AWS identity (this is the identity that will be cluster admin):

```powershell
aws sts get-caller-identity
```

2. Ensure the cluster exists (Terraform outputs help here):

```powershell
terraform output
```

3. Pull kubeconfig for this cluster:

```powershell
aws eks update-kubeconfig --region eu-north-1 --name my-eks-cluster
```

4. Verify access:

```powershell
kubectl get nodes
kubectl get ns
```

If you see nodes listed, you are connected and ready to deploy workloads.

## Cluster access methods (bastion, IAM user, IAM role)

This section is a walkthrough for three common access patterns. It does not change Terraform; it only shows commands you can run with the AWS CLI and `kubectl`.

### 1) Gather identifiers (one time)

```powershell
# Account ID and region
$ACCOUNT_ID = (aws sts get-caller-identity --query Account --output text)
$REGION = "<your-region>"
$CLUSTER = "<your-cluster-name>"
```

### 2) Create an IAM user (direct access)

```powershell
aws iam create-user --user-name bastion-user
aws iam create-access-key --user-name bastion-user
```

Create a minimal policy for EKS cluster discovery and authentication:

```powershell
aws iam create-policy --policy-name EksDescribeOnly --policy-document file://eks-describe.json
$POLICY_ARN = (aws iam list-policies --scope Local --query "Policies[?PolicyName=='EksDescribeOnly'].Arn | [0]" --output text)
aws iam attach-user-policy --user-name bastion-user --policy-arn $POLICY_ARN
```

Configure credentials on the machine that will run `kubectl`:

```powershell
aws configure --profile bastion-user
aws eks update-kubeconfig --region $REGION --name $CLUSTER --profile bastion-user
kubectl get nodes
```

### 3) Create an IAM role (assume-role access)

Create a role that can be assumed by a bastion EC2 instance:

```powershell
aws iam create-role --role-name bastion-eks-role --assume-role-policy-document file://bastion-trust.json
aws iam attach-role-policy --role-name bastion-eks-role --policy-arn $POLICY_ARN
aws iam create-instance-profile --instance-profile-name bastion-eks-profile
aws iam add-role-to-instance-profile --instance-profile-name bastion-eks-profile --role-name bastion-eks-role
```

Attach the instance profile to your bastion EC2 instance. Then on that bastion host:

```powershell
aws eks update-kubeconfig --region $REGION --name $CLUSTER
kubectl get nodes
```

#### IAM user assumes the role (no EC2 needed)

Use this trust policy if you want a specific IAM user to assume the role directly:

```powershell
aws iam create-role --role-name bastion-eks-role --assume-role-policy-document file://user-assume-role-trust.json
aws iam attach-role-policy --role-name bastion-eks-role --policy-arn $POLICY_ARN
```

Then assume the role and update kubeconfig:

```powershell
$ASSUME = aws sts assume-role --role-arn arn:aws:iam::$ACCOUNT_ID:role/bastion-eks-role --role-session-name bastion-session | ConvertFrom-Json
$env:AWS_ACCESS_KEY_ID = $ASSUME.Credentials.AccessKeyId
$env:AWS_SECRET_ACCESS_KEY = $ASSUME.Credentials.SecretAccessKey
$env:AWS_SESSION_TOKEN = $ASSUME.Credentials.SessionToken

aws eks update-kubeconfig --region $REGION --name $CLUSTER
kubectl get nodes
```

### 4) Grant Kubernetes access to the IAM user/role

You need *one* of the following methods. Pick the one you prefer and stick to it.

#### Option A: EKS access entries (recommended)

List available access policies and pick one (for example, an admin policy for full access):

```powershell
aws eks list-access-policies --region $REGION
```

Create access entries for the IAM user and/or role:

```powershell
aws eks create-access-entry --cluster-name $CLUSTER --principal-arn arn:aws:iam::$ACCOUNT_ID:user/bastion-user --type STANDARD --kubernetes-groups "system:masters"
aws eks create-access-entry --cluster-name $CLUSTER --principal-arn arn:aws:iam::$ACCOUNT_ID:role/bastion-eks-role --type STANDARD --kubernetes-groups "system:masters"
```

Associate a managed access policy (replace the policy ARN with one from `list-access-policies`):

```powershell
aws eks associate-access-policy --cluster-name $CLUSTER --principal-arn arn:aws:iam::$ACCOUNT_ID:user/bastion-user --policy-arn <access-policy-arn> --access-scope type=cluster
aws eks associate-access-policy --cluster-name $CLUSTER --principal-arn arn:aws:iam::$ACCOUNT_ID:role/bastion-eks-role --policy-arn <access-policy-arn> --access-scope type=cluster
```

#### Option B: `aws-auth` ConfigMap (legacy)

Use this if your cluster still relies on `aws-auth`. Make sure you preserve any existing entries.

Export the current ConfigMap, edit it, and apply back:

```powershell
kubectl -n kube-system get configmap aws-auth -o yaml | Set-Content -Path aws-auth.yaml
# Edit aws-auth.yaml in your editor, then apply:
kubectl apply -f aws-auth.yaml
```

IAM user entry example (add under `mapUsers`):

```yaml
- userarn: arn:aws:iam::<account-id>:user/bastion-user
  username: bastion-user
  groups:
    - system:masters
```

IAM role entry example (add under `mapRoles`):

```yaml
- rolearn: arn:aws:iam::<account-id>:role/bastion-eks-role
  username: bastion-eks-role
  groups:
    - system:masters
```

Full example (apply via `kubectl apply -f -` if you prefer inline):

```powershell
@'
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapUsers: |
    - userarn: arn:aws:iam::<account-id>:user/bastion-user
      username: bastion-user
      groups:
        - system:masters
  mapRoles: |
    - rolearn: arn:aws:iam::<account-id>:role/bastion-eks-role
      username: bastion-eks-role
      groups:
        - system:masters
'@ | kubectl apply -f -
```

Replace `<account-id>` with your AWS account ID.

## Common issues (quick fixes)

- `kubectl: command not found`: Install kubectl, then retry the steps above.
- `You must be logged in to the server`: The AWS identity in step 1 does not have EKS admin access.
  Re-run Terraform with the intended identity or update EKS access entries/IAM.
- `No nodes found`: The cluster control plane is up, but node group is still creating.
  Wait a few minutes and re-run `kubectl get nodes`.

## Cost Management

### Estimated Monthly Costs

| Resource | Always Running | Per Hour |
|----------|----------------|----------|
| EKS Control Plane | ~$72/month | $0.10/hour |
| NAT Gateway | ~$32/month | $0.045/hour |
| t3.medium EC2 (×2) | ~$60/month | $0.084/hour |
| EBS Volumes | ~$6/month | - |
| **Total (24/7)** | **~$170/month** | - |

### Cost Optimization for Dev/Learning

For occasional use (4-6 hours, 3-5 times/week), **destroy infrastructure after each session**:

| Usage | Estimated Cost |
|-------|----------------|
| 4 hrs × 3 sessions/week | ~$11/month |
| 6 hrs × 5 sessions/week | ~$27/month |

### Quick Start/Stop Scripts

Use the provided scripts to easily start and stop your cluster:

**PowerShell (Windows):**
```powershell
# Start cluster (15-25 min)
.\start-cluster.ps1

# Stop cluster and save costs
.\stop-cluster.ps1
```

**Bash (Linux/Mac):**
```bash
# Start cluster (15-25 min)
./start-cluster.sh

# Stop cluster and save costs
./stop-cluster.sh
```

### Manual Commands

```powershell
# Start: Apply all infrastructure
terraform apply

# Stop: Destroy everything (stops all costs)
terraform destroy
```

## Destroy (cleanup)

```powershell
terraform destroy
```

## Notes and assumptions

- Default region is `ap-south-1`.
- The IAM identity running Terraform gets EKS admin access (`enable_cluster_creator_admin_permissions = true`).
- Node group defaults use `t3.medium` and on-demand capacity.
- NAT gateway is set to single for lower cost in non-production.
- EKS managed add-ons (coredns, kube-proxy, vpc-cni) are enabled by default.
- Cluster Autoscaler requires manual manifest deployment after cluster creation (see README).
- API endpoint is publicly accessible by default — restrict CIDRs for production.

## Suggested next improvements

1. ~~Use remote state (S3 + DynamoDB lock).~~ ✅ Done
2. ~~Restrict API endpoint access CIDRs for production clusters.~~ ✅ Done (variable added, configure in tfvars)
3. ~~Add EKS managed add-ons (coredns, kube-proxy, vpc-cni).~~ ✅ Done
4. ~~Implement Cluster Autoscaler for dynamic scaling.~~ ✅ Done (IRSA role + manifest)
5. Add AWS Load Balancer Controller for Ingress support.
6. Add Metrics Server for `kubectl top` and HPA.
7. Add CloudWatch Container Insights for monitoring.
8. Replace broad admin access with fine-grained EKS access entries and Kubernetes RBAC groups.

## Recent Changes

### 2024-03
- Added remote state backend with S3 + DynamoDB
- Created `modules/state-storage/` for bootstrap resources
- Added `bootstrap-state-storage.tf` for state infrastructure
- Added EKS managed add-ons (coredns, kube-proxy, vpc-cni)
- Added Cluster Autoscaler IRSA role and Kubernetes manifest
- Added `cluster_endpoint_public_access_cidrs` variable for API security
- Added start/stop scripts for cost management
- Added cost estimation and optimization guide
- Removed `kubectl` binary from repository (use system-wide install)
- Updated `.gitignore` to exclude kubectl binary

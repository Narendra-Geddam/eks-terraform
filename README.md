# EKS on AWS with Terraform

This folder provisions a complete Amazon EKS environment in your AWS account using Terraform:

- VPC across 3 AZs
- Public and private subnets
- NAT gateway (single)
- EKS control plane
- EKS managed node group
- IAM OIDC provider (IRSA support)

## What I built

- [versions.tf](/c:/Users/don81/OneDrive/Desktop/DevOps/eks/terraform-eks/versions.tf): Terraform and provider version constraints
- [provider.tf](/c:/Users/don81/OneDrive/Desktop/DevOps/eks/terraform-eks/provider.tf): AWS provider + account/AZ data sources
- [variables.tf](/c:/Users/don81/OneDrive/Desktop/DevOps/eks/terraform-eks/variables.tf): All configurable inputs
- [main.tf](/c:/Users/don81/OneDrive/Desktop/DevOps/eks/terraform-eks/main.tf): VPC + EKS infrastructure
- [outputs.tf](/c:/Users/don81/OneDrive/Desktop/DevOps/eks/terraform-eks/outputs.tf): Useful outputs after apply
- [terraform.tfvars.example](/c:/Users/don81/OneDrive/Desktop/DevOps/eks/terraform-eks/terraform.tfvars.example): Example values to copy
- [.gitignore](/c:/Users/don81/OneDrive/Desktop/DevOps/eks/terraform-eks/.gitignore): Avoid committing state/secrets

## Prerequisites

- Terraform `>= 1.6.0`
- AWS CLI configured with credentials that can create VPC, IAM, EKS, EC2, and related resources
- Optional: `kubectl` to interact with the cluster

## Quick start (PowerShell)

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

## Destroy (cleanup)

```powershell
terraform destroy
```

## Notes and assumptions

- Default region is `ap-south-1`.
- The IAM identity running Terraform gets EKS admin access (`enable_cluster_creator_admin_permissions = true`).
- Node group defaults use `t3.medium` and on-demand capacity.
- NAT gateway is set to single for lower cost in non-production.

## Suggested next improvements

1. Use remote state (S3 + DynamoDB lock).
2. Restrict API endpoint access CIDRs.
3. Add add-ons (AWS Load Balancer Controller, metrics-server, ExternalDNS) through Terraform.
4. Replace broad admin access with fine-grained EKS access entries and Kubernetes RBAC groups.

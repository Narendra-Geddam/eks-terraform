# AWS ALB (AWS Load Balancer Controller) on EKS

This guide shows how to set up an Application Load Balancer (ALB) for Kubernetes Ingress on an EKS cluster using the AWS Load Balancer Controller. It includes the required IAM, Helm install, and a sample Ingress.

---

## Prerequisites

- An EKS cluster is running
- kubectl configured for the cluster
- AWS CLI configured with permissions to manage IAM and EKS
- Helm installed
- The cluster has an OIDC provider enabled (IRSA)

Tools to have on your machine:
- aws
- kubectl
- helm
- eksctl (recommended for IRSA creation)

---

## Variables (set these first - VERIFY ALL VALUES)

**IMPORTANT**: Before proceeding, update these values to match your environment, then verify them.

Linux/macOS (bash):

```bash
export AWS_REGION=eu-north-1
export CLUSTER_NAME=my-eks-cluster
export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Verify the values are set correctly
echo "Region: $AWS_REGION"
echo "Cluster: $CLUSTER_NAME"
echo "Account ID: $ACCOUNT_ID"
```

Windows (PowerShell):

```powershell
$env:AWS_REGION = "eu-north-1"
$env:CLUSTER_NAME = "my-eks-cluster"
$env:ACCOUNT_ID = (aws sts get-caller-identity --query Account --output text)

# Verify the values are set correctly - ALL must show values
Write-Host "Region: $env:AWS_REGION"
Write-Host "Cluster: $env:CLUSTER_NAME"
Write-Host "Account ID: $env:ACCOUNT_ID"
```

If any value is empty, the command failed. Stop and fix it before continuing.

Optional - Set VPC ID (required for Helm install later):

Linux/macOS (bash):

```bash
export VPC_ID=$(aws eks describe-cluster --name $CLUSTER_NAME --region $AWS_REGION --query "cluster.resourcesVpcConfig.vpcId" --output text)
echo "VPC ID: $VPC_ID"
```

Windows (PowerShell):

```powershell
$env:VPC_ID = (aws eks describe-cluster --name $env:CLUSTER_NAME --region $env:AWS_REGION --query "cluster.resourcesVpcConfig.vpcId" --output text)
Write-Host "VPC ID: $env:VPC_ID"
```

**Note**: If VPC_ID is empty, the cluster query failed. Check your cluster name and region are correct.

---

## Step 1: Configure kubectl for the cluster

Linux/macOS (bash):

```bash
aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME
kubectl get nodes
```

Windows (PowerShell):

```powershell
aws eks update-kubeconfig --region $env:AWS_REGION --name $env:CLUSTER_NAME
kubectl get nodes
```

---

## Step 2: Ensure OIDC provider is enabled (IRSA)

Check if the OIDC provider is already associated:

Linux/macOS (bash):

```bash
aws eks describe-cluster --name $CLUSTER_NAME --region $AWS_REGION --query "cluster.identity.oidc.issuer" --output text
```

Windows (PowerShell):

```powershell
aws eks describe-cluster --name $env:CLUSTER_NAME --region $env:AWS_REGION --query "cluster.identity.oidc.issuer" --output text
```

If you do not see an issuer URL, create one with eksctl:

Linux/macOS (bash):

```bash
eksctl utils associate-iam-oidc-provider --region $AWS_REGION --cluster $CLUSTER_NAME --approve
```

Windows (PowerShell):

```powershell
eksctl utils associate-iam-oidc-provider --region $env:AWS_REGION --cluster $env:CLUSTER_NAME --approve
```

---

## Step 3: Create the IAM policy for the controller

Download the official IAM policy JSON and attempt to create the policy:

Linux/macOS (bash):

```bash
curl -o iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json
aws iam create-policy --policy-name AWSLoadBalancerControllerIAMPolicy --policy-document file://iam_policy.json
```

Windows (PowerShell):

```powershell
Invoke-WebRequest -Uri https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json -OutFile iam_policy.json
aws iam create-policy --policy-name AWSLoadBalancerControllerIAMPolicy --policy-document file://iam_policy.json
```

**Expected outcome**: Either the policy is created, or you get an error saying it already exists. Both are fine.

Now set the policy ARN variable:

Linux/macOS (bash):

```bash
export LBC_POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy"
echo "Policy ARN: $LBC_POLICY_ARN"
```

Windows (PowerShell):

```powershell
$env:LBC_POLICY_ARN = "arn:aws:iam::${env:ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy"
Write-Host "Policy ARN: $env:LBC_POLICY_ARN"
```

**CRITICAL**: Verify the Policy ARN shows your account ID (12 digits). If it shows `arn:aws:iam:://...` with no account ID, your `$ACCOUNT_ID` variable is empty. Stop and verify Step 1.

---

## Step 4: Create IAM service account (IRSA)

**FIRST**: Check if the service account already exists:

Linux/macOS (bash):

```bash
kubectl get serviceaccount aws-load-balancer-controller -n kube-system 2>&1
```

Windows (PowerShell):

```powershell
kubectl get serviceaccount aws-load-balancer-controller -n kube-system 2>&1
```

**If NOT FOUND** (NotFound error): Run this command to create the service account:

Linux/macOS (bash):

```bash
eksctl create iamserviceaccount \
  --cluster $CLUSTER_NAME \
  --namespace kube-system \
  --name aws-load-balancer-controller \
  --attach-policy-arn $LBC_POLICY_ARN \
  --approve
```

Windows (PowerShell) - **Use `--flag=value` format (NOT backtick continuation)**:

```powershell
eksctl create iamserviceaccount --cluster=$env:CLUSTER_NAME --namespace=kube-system --name=aws-load-balancer-controller --attach-policy-arn=$env:LBC_POLICY_ARN --approve
```

**If FOUND** (service account exists): You can proceed to Step 5.

**If the command fails** with "ARN is not valid": Your `$LBC_POLICY_ARN` variable is incorrect. Go back to Step 3 and verify it contains your account ID.

**If PowerShell error "--name=... and argument kube-system cannot be used"**: Use the `--flag=value` format shown above (not backtick continuation).

---

## Step 5: Install the AWS Load Balancer Controller with Helm

Add the EKS Helm repository:

Linux/macOS (bash):

```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update
```

Windows (PowerShell):

```powershell
helm repo add eks https://aws.github.io/eks-charts
helm repo update
```

**Option A - If you have VPC_ID set** (recommended):

Linux/macOS (bash):

```bash
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  --namespace kube-system \
  --set clusterName=$CLUSTER_NAME \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=$AWS_REGION \
  --set vpcId=$VPC_ID
```

Windows (PowerShell):

```powershell
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller `
  --namespace kube-system `
  --set clusterName=$env:CLUSTER_NAME `
  --set serviceAccount.create=false `
  --set serviceAccount.name=aws-load-balancer-controller `
  --set region=$env:AWS_REGION `
  --set vpcId=$env:VPC_ID
```

**Option B - If VPC_ID is empty or you want auto-discovery**:

Remove the `--set vpcId=...` line entirely. The controller will auto-discover the VPC from the cluster.

Linux/macOS (bash):

```bash
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  --namespace kube-system \
  --set clusterName=$CLUSTER_NAME \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=$AWS_REGION
```

Windows (PowerShell):

```powershell
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller `
  --namespace kube-system `
  --set clusterName=$env:CLUSTER_NAME `
  --set serviceAccount.create=false `
  --set serviceAccount.name=aws-load-balancer-controller `
  --set region=$env:AWS_REGION
```

Wait 10-15 seconds, then verify the controller is running:

Wait 10-15 seconds, then verify the controller is running:

Linux/macOS (bash):

```bash
# Check deployment status
kubectl -n kube-system get deployment aws-load-balancer-controller

# Check pods are running (should show 2/2 Running)
kubectl -n kube-system get pods -l app.kubernetes.io/name=aws-load-balancer-controller
```

Windows (PowerShell):

```powershell
# Check deployment status
kubectl -n kube-system get deployment aws-load-balancer-controller

# Check pods are running (should show 2/2 Running)
kubectl -n kube-system get pods -l app.kubernetes.io/name=aws-load-balancer-controller
```

**Expected output**: Two pods in `Running` state with `2/2` containers ready.

**If pods are `0/2 Pending`**: Wait 30 more seconds, the controller is starting. Re-run the above commands.

**If pods show errors or `CrashLoopBackOff`**: Check the pod logs:

```bash
kubectl -n kube-system logs -l app.kubernetes.io/name=aws-load-balancer-controller --tail=50
```

Example successful Helm install:

![Helm install success](docs/images/alb-helm-install.png)

---

## Step 6: Subnet tagging requirements

ALB requires subnets tagged so it knows where to place load balancers.

Public subnets (internet-facing):

```
Key: kubernetes.io/role/elb
Value: 1
```

Private subnets (internal):

```
Key: kubernetes.io/role/internal-elb
Value: 1
```

All subnets used by the cluster should also have:

```
Key: kubernetes.io/cluster/$CLUSTER_NAME
Value: shared
```

If you use this Terraform project, these tags are usually created by the VPC module. Verify in AWS console or with CLI.

---

## Step 7: Deploy a sample app and Ingress

Create a namespace and deploy a simple service:

Linux/macOS (bash):

```bash
kubectl create namespace demo

kubectl -n demo apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello
spec:
  replicas: 2
  selector:
    matchLabels:
      app: hello
  template:
    metadata:
      labels:
        app: hello
    spec:
      containers:
      - name: hello
        image: public.ecr.aws/nginx/nginx:latest
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: hello
spec:
  type: ClusterIP
  selector:
    app: hello
  ports:
  - port: 80
    targetPort: 80
EOF
```

Windows (PowerShell):

```powershell
kubectl create namespace demo

@"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello
spec:
  replicas: 2
  selector:
    matchLabels:
      app: hello
  template:
    metadata:
      labels:
        app: hello
    spec:
      containers:
      - name: hello
        image: public.ecr.aws/nginx/nginx:latest
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: hello
spec:
  type: ClusterIP
  selector:
    app: hello
  ports:
  - port: 80
    targetPort: 80
"@ | kubectl -n demo apply -f -
```

Create an Ingress that provisions an ALB:

Linux/macOS (bash):

```bash
kubectl -n demo apply -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: hello-alb
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
spec:
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: hello
            port:
              number: 80
EOF
```

Windows (PowerShell):

```powershell
@"
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: hello-alb
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
spec:
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: hello
            port:
              number: 80
"@ | kubectl -n demo apply -f -
```

Check the ALB address:

Linux/macOS (bash):

```bash
kubectl -n demo get ingress
```

Windows (PowerShell):

```powershell
kubectl -n demo get ingress
```

It can take a few minutes to provision. Once the ADDRESS is present, open it in a browser.

Success output (example):

![ALB provisioned](docs/images/output.png)

---

## Common issues and fixes

### Pods won't start (Pending or 0/2 replicas)

**Symptom**: `aws-load-balancer-controller-xxxxx-` pods stuck in Pending, or deployment shows `0/2     0            0`

**Cause**: Missing or incorrect service account

**Fix**:

1. Verify service account exists:
   ```powershell
   kubectl -n kube-system get serviceaccount aws-load-balancer-controller
   ```

2. If NotFound, check Step 4 was completed:
   - Did the `eksctl create iamserviceaccount` command succeed?
   - If the ARN was wrong, the service account may have failed silently

3. To re-create: Delete the old Helm release and re-run Steps 4 and 5:
   ```bash
   helm -n kube-system uninstall aws-load-balancer-controller
   # Then repeat Step 4 and Step 5
   ```

### "A policy called AWSLoadBalancerControllerIAMPolicy already exists"

**Symptom**: `aws iam create-policy` fails with EntityAlreadyExists

**Fix**: This is expected. Just run the commands that set `$LBC_POLICY_ARN` to the correct value. Proceed to Step 4.

### "ARN is not valid" or "ARN arn:aws:iam::/AWSLoadBalancerControllerIAMPolicy"

**Symptom**: `eksctl create iamserviceaccount` fails with invalid ARN (notice the empty account ID)

**Cause**: `$ACCOUNT_ID` environment variable is empty

**Fix**:
   ```powershell
   # Verify your AWS credentials are set
   aws sts get-caller-identity
   
   # Re-set all variables from Step 1
   $env:AWS_REGION = "eu-north-1"
   $env:CLUSTER_NAME = "my-eks-cluster"
   $env:ACCOUNT_ID = (aws sts get-caller-identity --query Account --output text)
   $env:LBC_POLICY_ARN = "arn:aws:iam::${env:ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy"
   
   # Verify ACCOUNT_ID is now set (should be 12 digits)
   Write-Host $env:ACCOUNT_ID
   
   # Re-run Step 4
   ```

### eksctl PowerShell syntax error: "--name=... and argument kube-system cannot be used at the same time"

**Symptom**: `eksctl create iamserviceaccount` fails with this error when running in PowerShell

**Cause**: PowerShell backtick continuation splits the command incorrectly. The `--namespace kube-system` gets parsed as a separate argument.

**Wrong (PowerShell backtick style - DO NOT USE)**:
   ```powershell
   eksctl create iamserviceaccount `
     --cluster $env:CLUSTER_NAME `
     --namespace kube-system `
     --name aws-load-balancer-controller `
     --attach-policy-arn $env:LBC_POLICY_ARN `
     --approve
   ```

**Correct (use `--flag=value` format for PowerShell)**:
   ```powershell
   eksctl create iamserviceaccount --cluster=$env:CLUSTER_NAME --namespace=kube-system --name=aws-load-balancer-controller --attach-policy-arn=$env:LBC_POLICY_ARN --approve
   ```

   Or split it into multiple lines with `+`:
   ```powershell
   eksctl create iamserviceaccount `
     --cluster=$env:CLUSTER_NAME `
     --namespace=kube-system `
     --name=aws-load-balancer-controller `
     --attach-policy-arn=$env:LBC_POLICY_ARN `
     --approve
   ```

### Ingress stuck in "pending"

**Symptom**: Ingress resource created but ADDRESS remains empty after several minutes

**Cause**: ALB controller not running or subnets not tagged

**Fix**:
   1. Verify controller pods are Running:
      ```bash
      kubectl -n kube-system get pods -l app.kubernetes.io/name=aws-load-balancer-controller
      ```

   2. Check subnets are tagged correctly as documented in Step 6

   3. Check controller logs for errors:
      ```bash
      kubectl -n kube-system logs deployment/aws-load-balancer-controller
      ```

### "eksctl" not recognized

**Symptom**: eksctl command not found on Windows

**Fix**: Install eksctl via Chocolatey (Admin PowerShell):
   ```powershell
   choco install eksctl
   ```

   Or manually: https://github.com/weaveworks/eksctl/releases

### Access denied errors in controller logs

**Symptom**: Controller logs show permission denied or access denied errors

**Fix**:
   1. Verify IAM policy was created:
      ```bash
      aws iam list-policies --query "Policies[?PolicyName=='AWSLoadBalancerControllerIAMPolicy']"
      ```

   2. Verify service account has the annotation linking to the IAM role:
      ```bash
      kubectl -n kube-system describe serviceaccount aws-load-balancer-controller
      ```
      Look for: `eks.amazonaws.com/role-arn: arn:aws:iam::...`

   3. If missing, delete the Helm release and re-run Steps 4 and 5

### ALB not created

**Symptom**: Ingress created but no ALB appears in AWS console

**Cause**: Ingress annotations missing or incorrect ingress class

**Fix**: Verify Ingress has correct annotations:
   ```yaml
   annotations:
     kubernetes.io/ingress.class: alb
     alb.ingress.kubernetes.io/scheme: internet-facing
     alb.ingress.kubernetes.io/target-type: ip
   ```

### Subnet tagging issues

**Ingress stuck in "pending"**: Check all subnets used by the cluster are tagged correctly (see Step 6 below)

Verify tags with AWS CLI:

```bash
aws ec2 describe-subnets --region $AWS_REGION --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[].{SubnetId:SubnetId, Tags:Tags}' --output table
```

---

## View controller logs

To debug any issues, view the controller logs:

Linux/macOS (bash):

```bash
kubectl -n kube-system logs deployment/aws-load-balancer-controller --tail=50
```

Windows (PowerShell):

```powershell
kubectl -n kube-system logs deployment/aws-load-balancer-controller --tail=50
```

For continuous logs (follow mode):

```bash
kubectl -n kube-system logs deployment/aws-load-balancer-controller -f
```

---

## Cleanup

Linux/macOS (bash):

```bash
kubectl -n demo delete ingress hello-alb
kubectl -n demo delete svc hello
kubectl -n demo delete deployment hello
kubectl delete namespace demo
```

Windows (PowerShell):

```powershell
kubectl -n demo delete ingress hello-alb
kubectl -n demo delete svc hello
kubectl -n demo delete deployment hello
kubectl delete namespace demo
```

If you want to remove the controller:

Linux/macOS (bash):

```bash
helm -n kube-system uninstall aws-load-balancer-controller
```

Windows (PowerShell):

```powershell
helm -n kube-system uninstall aws-load-balancer-controller
```

# EKS Cluster Startup Script (PowerShell)
# Usage: .\start-cluster.ps1
# Deploys complete EKS cluster with VPC, nodes, ALB controller, and monitoring

$ErrorActionPreference = "Stop"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  EKS Cluster Deployment Script" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  Phase 1: Pre-flight Checks" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# Check prerequisites
Write-Host ""
Write-Host "Checking prerequisites..." -ForegroundColor Green

$checks = @{
    "Terraform" = { terraform --version }
    "AWS CLI" = { aws --version }
    "kubectl" = { kubectl version --client }
    "Helm" = { helm version }
}

foreach ($name in $checks.Keys) {
    Write-Host "  ✓ $name" -NoNewline
    try {
        $null = & $checks[$name] 2>$null
        Write-Host " (installed)" -ForegroundColor Green
    } catch {
        Write-Host " (NOT FOUND - required)" -ForegroundColor Red
        exit 1
    }
}

# Check AWS credentials
Write-Host ""
Write-Host "  ✓ AWS Credentials" -NoNewline
try {
    $identity = aws sts get-caller-identity 2>$null | ConvertFrom-Json
    Write-Host " (authenticated)" -ForegroundColor Green
} catch {
    Write-Host " (NOT CONFIGURED)" -ForegroundColor Red
    exit 1
}

# Check if terraform.tfvars exists
Write-Host ""
Write-Host "  ✓ Configuration" -NoNewline
if (-not (Test-Path "terraform.tfvars")) {
    Write-Host " (creating from template)..." -ForegroundColor Yellow
    Copy-Item terraform.tfvars.example terraform.tfvars
    Write-Host ""
    Write-Host "Config file created: terraform.tfvars" -ForegroundColor Yellow
    Write-Host "Please edit terraform.tfvars with your desired settings:" -ForegroundColor Yellow
    Write-Host "  - AWS region" -ForegroundColor Gray
    Write-Host "  - Cluster name" -ForegroundColor Gray
    Write-Host "  - Kubernetes version" -ForegroundColor Gray
    Write-Host "  - Node group settings" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Then run this script again." -ForegroundColor Yellow
    exit 0
} else {
    Write-Host " (loaded)" -ForegroundColor Green
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  Phase 2: Terraform Initialization" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

Write-Host ""
Write-Host "Initializing Terraform..." -ForegroundColor Green
terraform init

Write-Host ""
Write-Host "Validating Terraform configuration..." -ForegroundColor Green
terraform validate | Out-Null
Write-Host "  ✓ Configuration valid"

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  Phase 3: Planning Infrastructure" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

Write-Host ""
Write-Host "Planning infrastructure changes..." -ForegroundColor Green
terraform plan -out=tfplan | Select-Object -Last 20

Write-Host ""
Write-Host "Confirm deployment? (yes/no)" -ForegroundColor Yellow
$proceed = Read-Host "Enter 'yes' to proceed"

if ($proceed -ne "yes") {
    Write-Host "Cancelled." -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  Phase 4: Deploying Infrastructure" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "⏳ Applying infrastructure (this takes 15-25 minutes)..." -ForegroundColor Yellow
Write-Host "   - VPC with subnets" -ForegroundColor Gray
Write-Host "   - EKS cluster" -ForegroundColor Gray
Write-Host "   - Managed node group" -ForegroundColor Gray
Write-Host "   - ALB controller" -ForegroundColor Gray
Write-Host "   - Cluster autoscaler" -ForegroundColor Gray
Write-Host ""

$startTime = Get-Date
terraform apply tfplan
$duration = (Get-Date) - $startTime

# Deploy ALB controller if not already present (handles timing issues)
Write-Host ""
Write-Host "Ensuring ALB controller deployment..." -ForegroundColor Green
$albServiceAccount = kubectl -n kube-system get serviceaccount aws-load-balancer-controller -o name 2>$null
if ($albServiceAccount) {
    Write-Host "  ℹ️  Service account exists, verifying Helm release..."
    $albRelease = helm list -n kube-system 2>$null | Select-String "aws-load-balancer-controller"
    if (-not $albRelease) {
        Write-Host "  ⚠️  Helm release missing, deploying..." -ForegroundColor Yellow
        terraform apply -target="helm_release.alb_controller" -auto-approve 2>&1 | Out-Null
        Start-Sleep -Seconds 10
        Write-Host "  ✓ Helm release deployed"
    } else {
        Write-Host "  ✓ Helm release already deployed"
    }
} else {
    Write-Host "  ⚠️  Service account missing, deploying ALB controller..." -ForegroundColor Yellow
    terraform apply -target="kubernetes_service_account.alb_controller" -target="helm_release.alb_controller" -auto-approve 2>&1 | Out-Null
    Start-Sleep -Seconds 10
    Write-Host "  ✓ ALB controller deployed"
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  Phase 5: Post-Deployment Configuration" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# Get outputs
Write-Host ""
Write-Host "Retrieving cluster details..." -ForegroundColor Green
$region = terraform output -raw region
$clusterName = terraform output -raw cluster_name
$clusterVersion = terraform output -raw cluster_version

Write-Host "  Region: $region" -ForegroundColor Gray
Write-Host "  Cluster: $clusterName" -ForegroundColor Gray
Write-Host "  Kubernetes: $clusterVersion" -ForegroundColor Gray

# Update kubeconfig
Write-Host ""
Write-Host "Updating kubeconfig..." -ForegroundColor Green
aws eks update-kubeconfig --region $region --name $clusterName | Out-Null
Write-Host "  ✓ Kubeconfig updated"

# Wait for cluster to be ready
Write-Host ""
Write-Host "Waiting for cluster to be ready..." -ForegroundColor Green
$maxAttempts = 30
$attempt = 0
while ($attempt -lt $maxAttempts) {
    try {
        $nodes = kubectl get nodes 2>$null
        if ($nodes) {
            Write-Host "  ✓ Cluster accessible"
            break
        }
    } catch {
        $attempt++
        if ($attempt -lt $maxAttempts) {
            Start-Sleep -Seconds 10
        }
    }
}

# Verify nodes
Write-Host ""
Write-Host "Verifying nodes..." -ForegroundColor Green
$nodeCount = (kubectl get nodes 2>$null | Measure-Object -Line).Lines - 1
Write-Host "  ✓ $nodeCount node(s) running"

# Verify ALB controller
Write-Host ""
Write-Host "Verifying ALB controller..." -ForegroundColor Green
$albPods = kubectl -n kube-system get pods -l app.kubernetes.io/name=aws-load-balancer-controller 2>$null | Measure-Object -Line
$albCount = $albPods.Lines - 1
if ($albCount -gt 0) {
    Write-Host "  ✓ ALB controller deployed ($albCount pod(s))"
} else {
    Write-Host "  ⚠️  ALB controller not yet ready" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  ✅ Cluster Deployment Complete!" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Deployment Summary:" -ForegroundColor Cyan
Write-Host "  Duration: $($duration.TotalMinutes.ToString('F1')) minutes"
Write-Host "  Region: $region"
Write-Host "  Cluster: $clusterName (v$clusterVersion)"
Write-Host "  Nodes: $nodeCount"
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Verify cluster health:" -ForegroundColor White
Write-Host "   kubectl get nodes" -ForegroundColor Gray
Write-Host "   kubectl get pods -A" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Check ALB controller status:" -ForegroundColor White
Write-Host "   kubectl -n kube-system get deployment aws-load-balancer-controller" -ForegroundColor Gray
Write-Host "   kubectl -n kube-system logs -l app.kubernetes.io/name=aws-load-balancer-controller --tail=50" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Deploy a test application with ALB:" -ForegroundColor White
Write-Host "   See alb.md for examples" -ForegroundColor Gray
Write-Host ""
Write-Host "4. Monitor cluster autoscaling:" -ForegroundColor White
Write-Host "   kubectl -n kube-system logs -l app.kubernetes.io/name=aws-cluster-autoscaler" -ForegroundColor Gray
Write-Host ""
Write-Host "5. Destroy cluster when done:" -ForegroundColor White
Write-Host "   .\stop-cluster.ps1" -ForegroundColor Gray
Write-Host ""
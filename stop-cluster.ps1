# EKS Cluster Shutdown (PowerShell)
# Usage: .\stop-cluster.ps1
# This script cleanly destroys all infrastructure including ALBs, services, and Terraform resources

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  EKS Cluster Destruction Script" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "This will DESTROY all infrastructure:" -ForegroundColor Yellow
Write-Host "   - Kubernetes resources (Deployments, Services, Ingress)" -ForegroundColor Red
Write-Host "   - Helm releases (ALB Controller)" -ForegroundColor Red
Write-Host "   - EKS Cluster" -ForegroundColor Red
Write-Host "   - VPC and networking" -ForegroundColor Red
Write-Host "   - IAM roles and security groups" -ForegroundColor Red
Write-Host "   - Terraform state files" -ForegroundColor Red
Write-Host ""
Write-Host "Cost savings: ~`$110-170/month" -ForegroundColor Green
Write-Host ""

$confirm = Read-Host "Are you sure? Type 'yes' to proceed"

if ($confirm -ne "yes") {
    Write-Host "Cancelled." -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  Phase 1: Cleaning Kubernetes Resources" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# Clean up Helm releases in kube-system
Write-Host ""
Write-Host "Deleting Helm releases..." -ForegroundColor Green
$helmReleases = @(
    "aws-load-balancer-controller",
    "karpenter",
    "cluster-autoscaler",
    "monitoring"
)

foreach ($release in $helmReleases) {
    Write-Host "  - Checking for $release..." -NoNewline
    $exists = helm list -n kube-system 2>$null | Select-String -Pattern $release
    if ($exists) {
        Write-Host " Deleting..." -ForegroundColor Yellow
        helm uninstall $release -n kube-system 2>$null
    } else {
        Write-Host " Not found (skipped)" -ForegroundColor Gray
    }
}

# Delete all Ingress resources
Write-Host ""
Write-Host "Deleting Ingress resources..." -ForegroundColor Green
kubectl delete ingress --all --all-namespaces --ignore-not-found=true 2>$null
Write-Host "  ✓ Ingress resources deleted"

# Delete all LoadBalancer services (triggers ALB deletion)
Write-Host ""
Write-Host "Deleting LoadBalancer services..." -ForegroundColor Green
$services = kubectl get svc -A -o json 2>$null | ConvertFrom-Json
$lbCount = ($services.items | Where-Object { $_.spec.type -eq "LoadBalancer" }).Count

if ($lbCount -gt 0) {
    Write-Host "  Found $lbCount LoadBalancer(s), deleting..." -ForegroundColor Yellow
    kubectl delete svc --all --all-namespaces --ignore-not-found=true 2>$null
    Write-Host "  Waiting 30s for ALBs to be deprovisioned..." -ForegroundColor Cyan
    Start-Sleep -Seconds 30
} else {
    Write-Host "  No LoadBalancer services found" -ForegroundColor Gray
}

# Delete all deployments and pods
Write-Host ""
Write-Host "Deleting Kubernetes deployments and pods..." -ForegroundColor Green
kubectl delete deployment --all --all-namespaces --ignore-not-found=true 2>$null
kubectl delete daemonset --all --all-namespaces --ignore-not-found=true 2>$null
kubectl delete statefulset --all --all-namespaces --ignore-not-found=true 2>$null
Write-Host "  ✓ Deployments deleted"

# Delete all namespaces except system ones
Write-Host ""
Write-Host "Deleting custom namespaces..." -ForegroundColor Green
$nsToDelete = kubectl get ns -o json 2>$null | ConvertFrom-Json | Where-Object { $_.metadata.name -notmatch "kube-|default" } | Select-Object -ExpandProperty metadata.name
if ($nsToDelete) {
    foreach ($ns in $nsToDelete) {
        Write-Host "  - Deleting namespace: $ns" -ForegroundColor Yellow
        kubectl delete ns $ns --ignore-not-found=true 2>$null
    }
}
Write-Host "  ✓ Custom namespaces deleted"

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  Phase 2: Destroying Infrastructure (Terraform)" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

terraform destroy --auto-approve

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  Phase 3: Cleanup" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# Clean up local Terraform files
Write-Host ""
Write-Host "Cleaning up Terraform state files..." -ForegroundColor Green
if (Test-Path .terraform) {
    Remove-Item -Recurse -Force .terraform 2>$null | Out-Null
    Write-Host "  ✓ Removed .terraform directory"
}

if (Test-Path terraform.tfstate) {
    Remove-Item -Force terraform.tfstate 2>$null | Out-Null
    Write-Host "  ✓ Removed terraform.tfstate"
}

if (Test-Path terraform.tfstate.backup) {
    Remove-Item -Force terraform.tfstate.backup 2>$null | Out-Null
    Write-Host "  ✓ Removed terraform.tfstate.backup"
}

# Clean up old backup files
Get-ChildItem terraform.tfstate.*.backup -ErrorAction SilentlyContinue | ForEach-Object {
    Remove-Item $_ -Force 2>$null
    Write-Host "  ✓ Removed $($_.Name)"
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  ✅ Cluster Completely Destroyed!" -ForegroundColor Green
Write-Host "  💰 All costs have stopped" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Verify resources deleted in AWS Console: https://console.aws.amazon.com" -ForegroundColor Gray
Write-Host "  2. Check S3 bucket emptied (state bucket): eks-terraform-state-*" -ForegroundColor Gray
Write-Host "  3. To redeploy: Run .\start-cluster.ps1" -ForegroundColor Gray
Write-Host ""
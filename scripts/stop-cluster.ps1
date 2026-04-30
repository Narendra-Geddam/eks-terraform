# EKS Cluster Shutdown (PowerShell)
# Usage: .\scripts\stop-cluster.ps1
# This script cleanly destroys all infrastructure including ALBs, services, and Terraform resources

param(
    [string]$EnvironmentName = $(if ($env:EKS_ENVIRONMENT_NAME) { $env:EKS_ENVIRONMENT_NAME } else { "prod" })
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$EnvironmentPath = Join-Path $ScriptDir "..\infra\environments\$EnvironmentName"
if (-not (Test-Path $EnvironmentPath)) {
    Write-Host "Environment folder not found: $EnvironmentPath" -ForegroundColor Red
    Write-Host "Set -EnvironmentName or EKS_ENVIRONMENT_NAME to a valid environment directory under infra/environments." -ForegroundColor Yellow
    exit 1
}

$TerraformDir = (Resolve-Path $EnvironmentPath).Path
Set-Location $TerraformDir

function Get-TfVarValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $content = Get-Content terraform.tfvars -Raw
    $pattern = '(?m)^\s*' + [regex]::Escape($Name) + '\s*=\s*"([^"]+)"'
    if ($content -match $pattern) {
        return $Matches[1]
    }

    return $null
}

function Test-LiveEksCluster {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Region,
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $null = aws eks describe-cluster --region $Region --name $Name 2>$null
    return ($LASTEXITCODE -eq 0)
}

function Remove-LiveEksCluster {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Region,
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if (-not (Test-LiveEksCluster -Region $Region -Name $Name)) {
        Write-Host "  ✓ No live EKS cluster found" -ForegroundColor Gray
        return $true
    }

    Write-Host "  Found live EKS cluster '$Name' in $Region; deleting it directly..." -ForegroundColor Yellow

    $nodeGroupsJson = aws eks list-nodegroups --region $Region --cluster-name $Name --output json 2>$null | ConvertFrom-Json
    foreach ($nodeGroup in @($nodeGroupsJson.nodegroups)) {
        if ([string]::IsNullOrWhiteSpace($nodeGroup)) {
            continue
        }

        Write-Host "    - Deleting node group: $nodeGroup" -ForegroundColor Yellow
        aws eks delete-nodegroup --region $Region --cluster-name $Name --nodegroup-name $nodeGroup 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "    ✗ Failed to delete node group: $nodeGroup" -ForegroundColor Red
            return $false
        }

        aws eks wait nodegroup-deleted --region $Region --cluster-name $Name --nodegroup-name $nodeGroup 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "    ✗ Timed out waiting for node group deletion: $nodeGroup" -ForegroundColor Red
            return $false
        }
    }

    Write-Host "  Deleting EKS cluster..." -ForegroundColor Yellow
    aws eks delete-cluster --region $Region --name $Name 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ✗ Failed to start cluster deletion" -ForegroundColor Red
        return $false
    }

    aws eks wait cluster-deleted --region $Region --name $Name 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ✗ Timed out waiting for cluster deletion" -ForegroundColor Red
        return $false
    }

    Write-Host "  ✓ EKS cluster deleted" -ForegroundColor Green
    return $true
}

$awsRegion = Get-TfVarValue -Name "aws_region"
if (-not $awsRegion) { $awsRegion = "ap-south-1" }

$clusterName = Get-TfVarValue -Name "cluster_name"
if (-not $clusterName) { $clusterName = "eks-cluster" }

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
$systemNamespaces = @(
    "default",
    "kube-system",
    "kube-public",
    "kube-node-lease"
)
$nsToDelete = kubectl get ns -o json 2>$null |
    ConvertFrom-Json |
    ForEach-Object { $_.items } |
    Where-Object { $systemNamespaces -notcontains $_.metadata.name } |
    ForEach-Object { $_.metadata.name }
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

Write-Host "Initializing Terraform for destroy..." -ForegroundColor Green
terraform init -input=false
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "❌ Terraform init failed - destroy cannot continue" -ForegroundColor Red
    exit $LASTEXITCODE
}

$destroyOutput = terraform destroy --auto-approve 2>&1

# Check if destroy succeeded
$destroySuccess = $LASTEXITCODE -eq 0

Write-Host ""
if ($destroySuccess) {
    Write-Host ""
    if (Test-LiveEksCluster -Region $awsRegion -Name $clusterName) {
        $clusterDeleted = Remove-LiveEksCluster -Region $awsRegion -Name $clusterName
        if (-not $clusterDeleted) {
            Write-Host ""
            Write-Host "❌ EKS cluster still exists - state files preserved" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "  ✓ EKS cluster already absent" -ForegroundColor Gray
    }

    Write-Host "✅ Terraform destroy completed successfully" -ForegroundColor Green
} else {
    Write-Host "⚠️  Terraform destroy had errors - checking what failed..." -ForegroundColor Yellow
    $destroyOutput | Select-String -Pattern "Error|error" | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  Phase 3: Cleanup" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# IMPORTANT: Only delete state files if destroy was successful
if ($destroySuccess) {
    Write-Host ""
    Write-Host "Cleaning up local Terraform files..." -ForegroundColor Green
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
    Write-Host "  ✅ Cluster Successfully Destroyed!" -ForegroundColor Green
    Write-Host "  💰 All costs have stopped" -ForegroundColor Green
    Write-Host "==========================================" -ForegroundColor Cyan
} else {
    Write-Host ""
    Write-Host "❌ DESTRUCTION FAILED - STATE FILES PRESERVED" -ForegroundColor Red
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "  State files kept so you can retry cleanup:" -ForegroundColor Yellow
    Write-Host "  - terraform.tfstate (exists)" -ForegroundColor Yellow
    Write-Host "  - .terraform/ directory (exists)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  To retry:" -ForegroundColor Yellow
    Write-Host "    1. Fix the errors above" -ForegroundColor Yellow
    Write-Host "    2. Run: terraform destroy --auto-approve" -ForegroundColor Yellow
    Write-Host "    3. Run this script again: ..\..\..\scripts\stop-cluster.ps1" -ForegroundColor Yellow
    Write-Host "==========================================" -ForegroundColor Cyan
    exit 1
}

Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Verify resources deleted in AWS Console: https://console.aws.amazon.com" -ForegroundColor Gray
Write-Host "  2. Check S3 bucket emptied (state bucket): eks-terraform-state-*" -ForegroundColor Gray
Write-Host "  3. To redeploy: Run ..\..\..\scripts\start-cluster.ps1" -ForegroundColor Gray
Write-Host ""
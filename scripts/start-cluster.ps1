# EKS Cluster Startup Script (PowerShell)
# Usage: .\scripts\start-cluster.ps1
# Deploys complete EKS cluster with VPC, nodes, ALB controller, and monitoring

param(
    [string]$EnvironmentName = $(if ($env:EKS_ENVIRONMENT_NAME) { $env:EKS_ENVIRONMENT_NAME } else { "prod" })
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$EnvironmentPath = Join-Path $ScriptDir "..\infra\environments\$EnvironmentName"
if (-not (Test-Path $EnvironmentPath)) {
    Write-Host "Environment folder not found: $EnvironmentPath" -ForegroundColor Red
    Write-Host "Set -EnvironmentName or EKS_ENVIRONMENT_NAME to a valid environment directory under infra/environments." -ForegroundColor Yellow
    exit 1
}

$TerraformDir = (Resolve-Path $EnvironmentPath).Path
Set-Location $TerraformDir

function Assert-LastExitCode {
    param(
        [string]$StepName,
        [int[]]$AllowedExitCodes = @(0)
    )

    if ($LASTEXITCODE -notin $AllowedExitCodes) {
        Write-Host ""
        Write-Host "  ✗ $StepName failed (exit code: $LASTEXITCODE)" -ForegroundColor Red
        exit $LASTEXITCODE
    }
}

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

function Test-TerraformStateContains {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Address
    )

    $stateAddresses = terraform state list 2>$null
    return $stateAddresses -contains $Address
}

function Import-TerraformResourceIfMissing {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Address,
        [Parameter(Mandatory = $true)]
        [string]$ResourceId,
        [Parameter(Mandatory = $true)]
        [string]$StepName
    )

    if ([string]::IsNullOrWhiteSpace($ResourceId)) {
        return
    }

    if (Test-TerraformStateContains -Address $Address) {
        Write-Host "  ↺ Replacing existing $StepName state with live resource ($ResourceId)..." -ForegroundColor Yellow
        terraform state rm $Address | Out-Null
        Assert-LastExitCode -StepName "terraform state rm for $StepName"
    }

    Write-Host "  ↺ Importing $StepName ($ResourceId)..." -ForegroundColor Yellow
    terraform import -input=false $Address $ResourceId | Out-Null
    Assert-LastExitCode -StepName "terraform import for $StepName"
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
    "AWS CLI"   = { aws --version }
    "kubectl"   = { kubectl version --client }
    "Helm"      = { helm version }
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

$awsRegion = Get-TfVarValue -Name "aws_region"
$clusterName = Get-TfVarValue -Name "cluster_name"
$vpcCidr = Get-TfVarValue -Name "vpc_cidr"
$projectName = Get-TfVarValue -Name "project_name"
$environment = Get-TfVarValue -Name "environment"

$clusterExists = $false
if ($awsRegion -and $clusterName) {
    $clusterExists = Test-LiveEksCluster -Region $awsRegion -Name $clusterName
}

$env:TF_VAR_enable_kubernetes_resources = if ($clusterExists) { "true" } else { "false" }

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  Phase 2: Terraform Initialization" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

Write-Host ""
Write-Host "Initializing Terraform..." -ForegroundColor Green
terraform init
Assert-LastExitCode -StepName "Terraform init"

Write-Host ""
Write-Host "Validating Terraform configuration..." -ForegroundColor Green
terraform validate | Out-Null
Assert-LastExitCode -StepName "Terraform validate"
Write-Host "  ✓ Configuration valid"

Write-Host ""
Write-Host "Refreshing Helm repositories..." -ForegroundColor Green
helm repo add eks https://aws.github.io/eks-charts --force-update | Out-Null
Assert-LastExitCode -StepName "helm repo add eks"
helm repo update | Out-Null
Assert-LastExitCode -StepName "helm repo update"
Write-Host "  ✓ Helm repositories refreshed"

Write-Host ""
Write-Host "Adopting existing AWS resources if they already exist..." -ForegroundColor Green

$vpcId = terraform output -raw vpc_id 2>$null
if ($LASTEXITCODE -ne 0) {
    $vpcId = $null
}

if (-not $vpcId -and $projectName -and $environment) {
    $vpcName = "$projectName-$environment-vpc"
    $vpcId = aws ec2 describe-vpcs --region $awsRegion --filters Name=tag:Name,Values=$vpcName --query 'Vpcs[0].VpcId' --output text 2>$null
    if ($vpcId -eq "None") {
        $vpcId = $null
    }
}

if ($vpcId) {
    $igwId = aws ec2 describe-internet-gateways --region $awsRegion --filters Name=attachment.vpc-id,Values=$vpcId --query 'InternetGateways[0].InternetGatewayId' --output text 2>$null
    if ($igwId -and $igwId -ne "None") {
        Import-TerraformResourceIfMissing -Address 'module.vpc.aws_internet_gateway.this[0]' -ResourceId $igwId -StepName 'VPC internet gateway'
    }

    $privateSubnetCidrs = @("10.20.0.0/20", "10.20.16.0/20", "10.20.32.0/20")
    for ($index = 0; $index -lt $privateSubnetCidrs.Count; $index++) {
        $cidrBlock = $privateSubnetCidrs[$index]
        $subnetId = aws ec2 describe-subnets --region $awsRegion --filters Name=vpc-id,Values=$vpcId Name=cidr-block,Values=$cidrBlock --query 'Subnets[0].SubnetId' --output text 2>$null
        if ($subnetId -and $subnetId -ne "None") {
            Import-TerraformResourceIfMissing -Address "module.vpc.aws_subnet.private[$index]" -ResourceId $subnetId -StepName "private subnet $cidrBlock"
        }
    }

    $logGroupName = "/aws/eks/$clusterName/cluster"
    $logGroupExists = aws logs describe-log-groups --region $awsRegion --log-group-name-prefix $logGroupName --query "logGroups[?logGroupName=='$logGroupName'].logGroupName | [0]" --output text 2>$null
    if ($logGroupExists -and $logGroupExists -ne "None") {
        Import-TerraformResourceIfMissing -Address 'module.eks.aws_cloudwatch_log_group.this[0]' -ResourceId $logGroupName -StepName 'EKS control plane log group'
    }

    $kmsAliasName = "alias/eks/$clusterName"
    $kmsAliasExists = aws kms list-aliases --region $awsRegion --query "Aliases[?AliasName=='$kmsAliasName'].AliasName | [0]" --output text 2>$null
    if ($kmsAliasExists -and $kmsAliasExists -ne "None") {
        Import-TerraformResourceIfMissing -Address 'module.eks.module.kms.aws_kms_alias.this["cluster"]' -ResourceId $kmsAliasName -StepName 'EKS KMS alias'
    }
} else {
    Write-Host "  ℹ️  No existing state output found yet; skipping import adoption" -ForegroundColor Gray
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  Phase 3: Planning Infrastructure" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

Write-Host ""
Write-Host "Planning infrastructure changes..." -ForegroundColor Green
$kubernetesResourceFlag = if ($clusterExists) { "true" } else { "false" }
$planOutput = terraform plan -detailed-exitcode -var="enable_kubernetes_resources=$kubernetesResourceFlag" -out=tfplan 2>&1
$planExitCode = $LASTEXITCODE

if ($planExitCode -eq 1) {
    Write-Host ""
    Write-Host "  ✗ Terraform plan failed" -ForegroundColor Red
    $planOutput | Select-Object -Last 40 | ForEach-Object { Write-Host "  $_" }
    exit 1
}

$hasChanges = $planExitCode -eq 2

if ($hasChanges) {
    $planOutput | Select-Object -Last 20 | ForEach-Object { Write-Host $_ }
    Write-Host ""
    Write-Host "Confirm deployment? (yes/no)" -ForegroundColor Yellow
    $proceed = Read-Host "Enter 'yes' to proceed"

    if ($proceed -ne "yes") {
        Write-Host "Cancelled." -ForegroundColor Yellow
        exit 0
    }
} else {
    Write-Host "  ✓ No infrastructure changes detected (idempotent run)" -ForegroundColor Green
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  Phase 4: Deploying Infrastructure" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

$startTime = Get-Date
$duration = [TimeSpan]::Zero

if ($hasChanges) {
    Write-Host "⏳ Applying infrastructure (this takes 15-25 minutes)..." -ForegroundColor Yellow
    Write-Host "   - VPC with subnets" -ForegroundColor Gray
    Write-Host "   - EKS cluster" -ForegroundColor Gray
    Write-Host "   - Managed node group" -ForegroundColor Gray
    Write-Host "   - ALB controller" -ForegroundColor Gray
    Write-Host "   - Cluster autoscaler" -ForegroundColor Gray
    Write-Host ""

    terraform apply -auto-approve tfplan
    Assert-LastExitCode -StepName "Terraform apply"
    $duration = (Get-Date) - $startTime
} else {
    Write-Host "Skipping apply because there are no pending changes." -ForegroundColor Green
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  Phase 5: Post-Deployment Configuration" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# If the cluster did not exist before this run, enable Kubernetes-managed resources now that the cluster can be queried.
if (-not $clusterExists) {
    Write-Host ""
    Write-Host "Enabling Kubernetes-managed resources after bootstrap..." -ForegroundColor Green
    $postBootstrapClusterExists = Test-LiveEksCluster -Region $awsRegion -Name $clusterName
    if (-not $postBootstrapClusterExists) {
        Write-Host "  ✗ EKS cluster is still not available for the Kubernetes phase" -ForegroundColor Red
        exit 1
    }

    $kubernetesResourceFlag = "true"
    terraform apply -auto-approve -var="enable_kubernetes_resources=$kubernetesResourceFlag"
    Assert-LastExitCode -StepName "Kubernetes resources apply"
}

# Get outputs
Write-Host ""
Write-Host "Retrieving cluster details..." -ForegroundColor Green
$region = terraform output -raw region
Assert-LastExitCode -StepName "Terraform output region"
$clusterName = terraform output -raw cluster_name
Assert-LastExitCode -StepName "Terraform output cluster_name"
$clusterVersion = terraform output -raw cluster_version
Assert-LastExitCode -StepName "Terraform output cluster_version"

Write-Host "  Region: $region" -ForegroundColor Gray
Write-Host "  Cluster: $clusterName" -ForegroundColor Gray
Write-Host "  Kubernetes: $clusterVersion" -ForegroundColor Gray

# Update kubeconfig
Write-Host ""
Write-Host "Updating kubeconfig..." -ForegroundColor Green
aws eks update-kubeconfig --region $region --name $clusterName | Out-Null
Assert-LastExitCode -StepName "aws eks update-kubeconfig"
Write-Host "  ✓ Kubeconfig updated"

# Wait for cluster to be ready
Write-Host ""
Write-Host "Waiting for cluster to be ready..." -ForegroundColor Green
$maxAttempts = 30
$attempt = 0
$clusterAccessible = $false

while ($attempt -lt $maxAttempts) {
    kubectl get nodes 1>$null 2>$null
    if ($LASTEXITCODE -eq 0) {
        $clusterAccessible = $true
        Write-Host "  ✓ Cluster accessible"
        break
    }

    $attempt++
    if ($attempt -lt $maxAttempts) {
        Start-Sleep -Seconds 10
    }
}

if (-not $clusterAccessible) {
    Write-Host "  ✗ Cluster is not reachable after waiting" -ForegroundColor Red
    exit 1
}

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
        Assert-LastExitCode -StepName "ALB Helm release deployment"
        Start-Sleep -Seconds 10
        Write-Host "  ✓ Helm release deployed"
    } else {
        Write-Host "  ✓ Helm release already deployed"
    }
} else {
    Write-Host "  ⚠️  Service account missing, deploying ALB controller..." -ForegroundColor Yellow
    terraform apply -target="kubernetes_service_account.alb_controller" -target="helm_release.alb_controller" -auto-approve 2>&1 | Out-Null
    Assert-LastExitCode -StepName "ALB controller deployment"
    Start-Sleep -Seconds 10
    Write-Host "  ✓ ALB controller deployed"
}

# Verify nodes
Write-Host ""
Write-Host "Verifying nodes..." -ForegroundColor Green
$nodeCount = (kubectl get nodes 2>$null | Measure-Object -Line).Lines - 1
if ($nodeCount -lt 0) { $nodeCount = 0 }
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
Write-Host "   See docs/guides/alb.md for examples" -ForegroundColor Gray
Write-Host ""
Write-Host "4. Monitor cluster autoscaling:" -ForegroundColor White
Write-Host "   kubectl -n kube-system logs -l app.kubernetes.io/name=aws-cluster-autoscaler" -ForegroundColor Gray
Write-Host ""
Write-Host "5. Destroy cluster when done:" -ForegroundColor White
Write-Host "   ..\..\..\scripts\stop-cluster.ps1" -ForegroundColor Gray
Write-Host ""
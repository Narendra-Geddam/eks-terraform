# EKS Cluster Quick Start (PowerShell)
# Usage: .\start-cluster.ps1

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  EKS Cluster Startup Script" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# Check if terraform.tfvars exists
if (-not (Test-Path "terraform.tfvars")) {
    Write-Host ""
    Write-Host "Creating terraform.tfvars from example..." -ForegroundColor Yellow
    Copy-Item terraform.tfvars.example terraform.tfvars
    Write-Host ""
    Write-Host "Please edit terraform.tfvars with your settings, then run this script again." -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "Initializing Terraform..." -ForegroundColor Green
terraform init

Write-Host ""
Write-Host "Planning infrastructure changes..." -ForegroundColor Green
terraform plan -out=tfplan

Write-Host ""
Write-Host "Applying infrastructure (this takes 15-25 minutes)..." -ForegroundColor Green
terraform apply tfplan

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Cluster Ready!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Connect to cluster:" -ForegroundColor White
Write-Host "     aws eks update-kubeconfig --region (terraform output -raw region) --name (terraform output -raw cluster_name)" -ForegroundColor Gray
Write-Host ""
Write-Host "  2. Deploy Cluster Autoscaler:" -ForegroundColor White
Write-Host "     terraform output -raw cluster_autoscaler_manifest | kubectl apply -f -" -ForegroundColor Gray
Write-Host ""
Write-Host "  3. Verify nodes:" -ForegroundColor White
Write-Host "     kubectl get nodes" -ForegroundColor Gray
# EKS Cluster Shutdown (PowerShell)
# Usage: .\stop-cluster.ps1

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  EKS Cluster Shutdown Script" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "This will DESTROY all infrastructure:" -ForegroundColor Yellow
Write-Host "   - EKS Cluster" -ForegroundColor Red
Write-Host "   - VPC and networking" -ForegroundColor Red
Write-Host "   - IAM roles" -ForegroundColor Red
Write-Host "   - S3 state bucket" -ForegroundColor Red
Write-Host "   - DynamoDB table" -ForegroundColor Red
Write-Host ""
Write-Host "Cost savings: ~`$110-170/month" -ForegroundColor Green
Write-Host ""

$confirm = Read-Host "Are you sure? (yes/no)"

if ($confirm -ne "yes") {
    Write-Host "Cancelled." -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "Destroying infrastructure..." -ForegroundColor Green
terraform destroy

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Cluster Destroyed - Cost Stopped!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Cyan
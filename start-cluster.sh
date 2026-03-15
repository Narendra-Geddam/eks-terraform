#!/bin/bash
# Quick start script - Initialize and deploy EKS cluster
# Usage: ./start-cluster.sh

set -e

echo "=========================================="
echo "  EKS Cluster Startup Script"
echo "=========================================="

# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
    echo "📝 Creating terraform.tfvars from example..."
    cp terraform.tfvars.example terraform.tfvars
    echo "⚠️  Please edit terraform.tfvars with your settings, then run this script again."
    exit 1
fi

echo ""
echo "📦 Initializing Terraform..."
terraform init

echo ""
echo "📋 Planning infrastructure changes..."
terraform plan -out=tfplan

echo ""
echo "🚀 Applying infrastructure (this takes 15-25 minutes)..."
terraform apply tfplan

echo ""
echo "=========================================="
echo "  ✅ Cluster Ready!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. Connect to cluster:"
echo "     aws eks update-kubeconfig --region \$(terraform output -raw region) --name \$(terraform output -raw cluster_name)"
echo ""
echo "  2. Deploy Cluster Autoscaler:"
echo "     terraform output -raw cluster_autoscaler_manifest | kubectl apply -f -"
echo ""
echo "  3. Verify nodes:"
echo "     kubectl get nodes"
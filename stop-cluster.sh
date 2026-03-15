#!/bin/bash
# Stop and destroy EKS cluster - Save costs when not in use
# Usage: ./stop-cluster.sh

set -e

echo "=========================================="
echo "  EKS Cluster Shutdown Script"
echo "=========================================="
echo ""
echo "⚠️  This will DESTROY all infrastructure:"
echo "   - EKS Cluster"
echo "   - VPC and networking"
echo "   - IAM roles"
echo "   - S3 state bucket"
echo "   - DynamoDB table"
echo ""
echo "Cost savings: ~$110-170/month"
echo ""

read -p "Are you sure? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "❌ Cancelled."
    exit 0
fi

echo ""
echo "🗑️  Destroying infrastructure..."
terraform destroy

echo ""
echo "=========================================="
echo "  ✅ Cluster Destroyed - Cost Stopped!"
echo "=========================================="
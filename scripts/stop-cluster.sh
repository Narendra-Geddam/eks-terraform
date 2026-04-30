#!/bin/bash
# Stop and destroy EKS cluster with comprehensive cleanup
# Usage: ./scripts/stop-cluster.sh
# Cleans all Kubernetes resources, Helm releases, and destroys infrastructure

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$(cd "$SCRIPT_DIR/../infra/environments/prod" && pwd)"
cd "$TERRAFORM_DIR"

echo "=========================================="
echo "  EKS Cluster Destruction Script"
echo "=========================================="
echo ""
echo "⚠️  This will DESTROY all infrastructure:"
echo "   - Kubernetes resources (Deployments, Services, Ingress)"
echo "   - Helm releases (ALB Controller)"
echo "   - EKS Cluster"
echo "   - VPC and networking"
echo "   - IAM roles and security groups"
echo "   - Terraform state files"
echo ""
echo "Cost savings: ~\$110-170/month"
echo ""

read -p "Are you sure? Type 'yes' to proceed: " confirm

if [ "$confirm" != "yes" ]; then
    echo "❌ Cancelled."
    exit 0
fi

# Check for jq; if missing we'll fall back to simpler parsing later
HAS_JQ=false
if command -v jq &>/dev/null; then
    HAS_JQ=true
fi

echo ""
echo "=========================================="
echo "  Phase 1: Cleaning Kubernetes Resources"
echo "=========================================="

# Delete Helm releases in kube-system
echo ""
echo "🗑️  Deleting Helm releases..."
HELM_RELEASES=("aws-load-balancer-controller" "karpenter" "cluster-autoscaler" "monitoring")

for release in "${HELM_RELEASES[@]}"; do
    echo -n "  - Checking for $release... "
    if helm list -n kube-system 2>/dev/null | grep -q "$release"; then
        echo "Deleting..."
        helm uninstall "$release" -n kube-system 2>/dev/null || true
    else
        echo "Not found (skipped)"
    fi
done

# Delete all Ingress resources
echo ""
echo "🗑️  Deleting Ingress resources..."
kubectl delete ingress --all --all-namespaces --ignore-not-found=true 2>/dev/null || true
echo "  ✓ Ingress resources deleted"

# Delete all LoadBalancer services (triggers ALB deletion)
echo ""
echo "🗑️  Deleting LoadBalancer services..."
if [ "$HAS_JQ" = true ]; then
    LOAD_BALANCERS=$(kubectl get svc -A -o json 2>/dev/null | jq -r '.items[] | select(.spec.type=="LoadBalancer") | .metadata.name' | wc -l)
else
    LOAD_BALANCERS=$(kubectl get svc -A 2>/dev/null | grep -c "LoadBalancer" || echo "0")
fi

if [ "$LOAD_BALANCERS" -gt 0 ]; then
    echo "  ⚠️  Found $LOAD_BALANCERS LoadBalancer(s), deleting..."
    kubectl delete svc --all --all-namespaces --ignore-not-found=true 2>/dev/null || true
    echo "  ⏳ Waiting 30s for ALBs to be deprovisioned..."
    sleep 30
else
    echo "  No LoadBalancer services found"
fi

# Delete all deployments and pods
echo ""
echo "🗑️  Deleting Kubernetes deployments, daemonsets, and statefulsets..."
kubectl delete deployment --all --all-namespaces --ignore-not-found=true 2>/dev/null || true
kubectl delete daemonset --all --all-namespaces --ignore-not-found=true 2>/dev/null || true
kubectl delete statefulset --all --all-namespaces --ignore-not-found=true 2>/dev/null || true
echo "  ✓ Deployments deleted"

# Delete custom namespaces
echo ""
echo "🗑️  Deleting custom namespaces..."
if [ "$HAS_JQ" = true ]; then
    CUSTOM_NS=$(kubectl get ns -o json 2>/dev/null | jq -r '.items[] | select(.metadata.name | test("^kube-|^default") | not) | .metadata.name')
else
    CUSTOM_NS=$(kubectl get ns 2>/dev/null | tail -n +2 | grep -v "^kube-" | grep -v "^default" | awk '{print $1}')
fi

if [ -n "$CUSTOM_NS" ]; then
    while IFS= read -r ns; do
        if [ -n "$ns" ]; then
            echo "  - Deleting namespace: $ns"
            kubectl delete ns "$ns" --ignore-not-found=true 2>/dev/null || true
        fi
    done <<< "$CUSTOM_NS"
fi
echo "  ✓ Custom namespaces deleted"

echo ""
echo "=========================================="
echo "  Phase 2: Destroying Infrastructure (Terraform)"
echo "=========================================="
echo ""

echo "Initializing Terraform (safe) before destroy..."
terraform init -input=false || true

echo "Destroying Terraform-managed resources..."
terraform destroy --auto-approve

echo ""
echo "=========================================="
echo "  Phase 3: Cleanup"
echo "=========================================="

# Clean up local Terraform files
echo ""
echo "🗑️  Cleaning up Terraform state files..."

if [ -d .terraform ]; then
    rm -rf .terraform
    echo "  ✓ Removed .terraform directory"
fi

if [ -f terraform.tfstate ]; then
    rm -f terraform.tfstate
    echo "  ✓ Removed terraform.tfstate"
fi

if [ -f terraform.tfstate.backup ]; then
    rm -f terraform.tfstate.backup
    echo "  ✓ Removed terraform.tfstate.backup"
fi

# Clean up old backup files
find . -maxdepth 1 -name "terraform.tfstate.*.backup" -type f -exec rm -f {} \; 2>/dev/null || true
echo "  ✓ Removed old backup files"

echo ""
echo "=========================================="
echo "  ✅ Cluster Completely Destroyed!"
echo "  💰 All costs have stopped"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. Verify resources deleted in AWS Console: https://console.aws.amazon.com"
echo "  2. Check S3 bucket emptied (state bucket): eks-terraform-state-*"
echo "  3. To redeploy: Run ../../../scripts/start-cluster.sh"
echo ""
#!/bin/bash
# EKS Cluster Startup Script (Bash)
# Usage: ./scripts/start-cluster.sh
# Deploys complete EKS cluster with VPC, nodes, ALB controller, and monitoring

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$(cd "$SCRIPT_DIR/../infra/environments/prod" && pwd)"
cd "$TERRAFORM_DIR"

echo "=========================================="
echo "  EKS Cluster Deployment Script"
echo "=========================================="
echo ""

echo "=========================================="
echo "  Phase 1: Pre-flight Checks"
echo "=========================================="

# Check prerequisites
echo ""
echo "Checking prerequisites..."

# Function to check if command exists
check_command() {
    if command -v $1 &> /dev/null; then
        echo "  ✓ $1 (installed)"
    else
        echo "  ✗ $1 (NOT FOUND - required)"
        exit 1
    fi
}

check_command terraform
check_command aws
check_command kubectl
check_command helm

# Check AWS credentials
echo ""
echo -n "  ✓ AWS Credentials "
if aws sts get-caller-identity &>/dev/null; then
    echo "(authenticated)"
else
    echo "(NOT CONFIGURED)"
    exit 1
fi

# Check if terraform.tfvars exists
echo ""
echo -n "  ✓ Configuration "
if [ ! -f "terraform.tfvars" ]; then
    echo "(creating from template)..."
    cp terraform.tfvars.example terraform.tfvars
    echo ""
    echo "Config file created: terraform.tfvars"
    echo "Please edit terraform.tfvars with your desired settings:"
    echo "  - AWS region"
    echo "  - Cluster name"
    echo "  - Kubernetes version"
    echo "  - Node group settings"
    echo ""
    echo "Then run this script again."
    exit 0
else
    echo "(loaded)"
fi

echo ""
echo "=========================================="
echo "  Phase 2: Terraform Initialization"
echo "=========================================="

echo ""
echo "Initializing Terraform..."
terraform init

echo ""
echo "Validating Terraform configuration..."
terraform validate > /dev/null
echo "  ✓ Configuration valid"

echo ""
echo "=========================================="
echo "  Phase 3: Planning Infrastructure"
echo "=========================================="

echo ""
echo "Planning infrastructure changes..."
set +e
PLAN_OUTPUT=$(terraform plan -detailed-exitcode -out=tfplan 2>&1)
PLAN_EXIT_CODE=$?
set -e

if [ $PLAN_EXIT_CODE -eq 1 ]; then
    echo ""
    echo "  ✗ Terraform plan failed"
    echo "$PLAN_OUTPUT" | tail -40
    exit 1
fi

HAS_CHANGES=false
if [ $PLAN_EXIT_CODE -eq 2 ]; then
    HAS_CHANGES=true
    echo "$PLAN_OUTPUT" | tail -20
else
    echo "  ✓ No infrastructure changes detected (idempotent run)"
fi

if [ "$HAS_CHANGES" = true ]; then
    echo ""
    read -p "Confirm deployment? (yes/no): " confirm

    if [ "$confirm" != "yes" ]; then
        echo "❌ Cancelled."
        exit 0
    fi
fi

echo ""
echo "=========================================="
echo "  Phase 4: Deploying Infrastructure"
echo "=========================================="
echo ""
echo "⏳ Applying infrastructure (this takes 15-25 minutes)..."
echo "   - VPC with subnets"
echo "   - EKS cluster"
echo "   - Managed node group"
echo "   - ALB controller"
echo "   - Cluster autoscaler"
echo ""

START_TIME=$(date +%s)
if [ "$HAS_CHANGES" = true ]; then
    terraform apply tfplan
else
    echo "Skipping apply because there are no pending changes."
fi
END_TIME=$(date +%s)
DURATION=$((($END_TIME - $START_TIME) / 60))

echo ""
echo "=========================================="
echo "  Phase 5: Post-Deployment Configuration"
echo "=========================================="

# Get outputs
echo ""
echo "Retrieving cluster details..."
REGION=$(terraform output -raw region)
CLUSTER_NAME=$(terraform output -raw cluster_name)
CLUSTER_VERSION=$(terraform output -raw cluster_version)

echo "  Region: $REGION"
echo "  Cluster: $CLUSTER_NAME"
echo "  Kubernetes: $CLUSTER_VERSION"

# Update kubeconfig
echo ""
echo "Updating kubeconfig..."
aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME > /dev/null
echo "  ✓ Kubeconfig updated"

# Wait for cluster to be ready
echo ""
echo "Waiting for cluster to be ready..."
MAX_ATTEMPTS=30
ATTEMPT=0

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    if kubectl get nodes &>/dev/null; then
        echo "  ✓ Cluster accessible"
        break
    fi
    ATTEMPT=$((ATTEMPT + 1))
    if [ $ATTEMPT -lt $MAX_ATTEMPTS ]; then
        sleep 10
    fi
done

# Verify nodes
echo ""
echo "Verifying nodes..."
NODE_COUNT=$(kubectl get nodes 2>/dev/null | tail -n +2 | wc -l)
echo "  ✓ $NODE_COUNT node(s) running"

# Verify ALB controller
echo ""
echo "Verifying ALB controller..."
ALB_PODS=$(kubectl -n kube-system get pods -l app.kubernetes.io/name=aws-load-balancer-controller 2>/dev/null | tail -n +2 | wc -l)

if [ $ALB_PODS -gt 0 ]; then
    echo "  ✓ ALB controller deployed ($ALB_PODS pod(s))"
else
    echo "  ⚠️  ALB controller not yet ready"
fi

echo ""
echo "=========================================="
echo "  ✅ Cluster Deployment Complete!"
echo "=========================================="
echo ""
echo "Deployment Summary:"
echo "  Duration: ${DURATION} minutes"
echo "  Region: $REGION"
echo "  Cluster: $CLUSTER_NAME (v$CLUSTER_VERSION)"
echo "  Nodes: $NODE_COUNT"
echo ""
echo "Next steps:"
echo ""
echo "1. Verify cluster health:"
echo "   kubectl get nodes"
echo "   kubectl get pods -A"
echo ""
echo "2. Check ALB controller status:"
echo "   kubectl -n kube-system get deployment aws-load-balancer-controller"
echo "   kubectl -n kube-system logs -l app.kubernetes.io/name=aws-load-balancer-controller --tail=50"
echo ""
echo "3. Deploy a test application with ALB:"
echo "   See docs/guides/alb.md for examples"
echo ""
echo "4. Monitor cluster autoscaling:"
echo "   kubectl -n kube-system logs -l app.kubernetes.io/name=aws-cluster-autoscaler"
echo ""
echo "5. Destroy cluster when done:"
echo "   ../../../scripts/stop-cluster.sh"
echo ""
# Manual AWS EKS Cleanup Script
# This script manually deletes all EKS-related resources when Terraform state is out of sync

param(
    [string]$Region = "eu-north-1",
    [string]$ClusterName = "my-eks-cluster",
    [string]$ProjectName = "my-platform"
)

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  AWS EKS Manual Cleanup Script" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "This will DELETE all EKS resources in region: $Region" -ForegroundColor Yellow
Write-Host "  - EKS Cluster: $ClusterName" -ForegroundColor Red
Write-Host "  - IAM Roles and Policies" -ForegroundColor Red
Write-Host "  - VPC and Security Groups" -ForegroundColor Red
Write-Host "  - S3 bucket and DynamoDB table" -ForegroundColor Red
Write-Host ""

$confirm = Read-Host "Are you sure? Type 'yes' to proceed"
if ($confirm -ne "yes") {
    Write-Host "Cancelled." -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  Phase 1: Delete EKS Cluster" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# Check if cluster exists
$clusterExists = aws eks describe-cluster --name $ClusterName --region $Region --output json 2>$null
if ($clusterExists) {
    Write-Host "Deleting EKS cluster: $ClusterName" -ForegroundColor Green
    
    # Get node groups
    $nodeGroups = aws eks list-nodegroups --cluster-name $ClusterName --region $Region --output json 2>$null | ConvertFrom-Json
    
    # Delete node groups first
    if ($nodeGroups.nodegroups) {
        foreach ($nodeGroup in $nodeGroups.nodegroups) {
            Write-Host "  Deleting node group: $nodeGroup" -ForegroundColor Yellow
            aws eks delete-nodegroup --cluster-name $ClusterName --nodegroup-name $nodeGroup --region $Region 2>$null
            
            Write-Host "  Waiting for node group deletion..." -ForegroundColor Gray
            aws eks wait nodegroup-deleted --cluster-name $ClusterName --nodegroup-name $nodeGroup --region $Region 2>$null
            Write-Host "  ✓ Node group deleted" -ForegroundColor Green
        }
    }
    
    # Delete cluster
    Write-Host "  Deleting EKS cluster..." -ForegroundColor Yellow
    aws eks delete-cluster --name $ClusterName --region $Region 2>$null
    
    Write-Host "  Waiting for cluster deletion..." -ForegroundColor Gray
    aws eks wait cluster-deleted --name $ClusterName --region $Region 2>$null
    Write-Host "  ✓ EKS cluster deleted" -ForegroundColor Green
} else {
    Write-Host "  ✓ EKS cluster not found (already deleted)" -ForegroundColor Gray
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  Phase 2: Delete IAM Roles and Policies" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# List of IAM roles to delete
$rolesToDelete = @(
    "${ClusterName}-alb-controller-role",
    "${ClusterName}-cluster-autoscaler",
    "${ClusterName}-eks-cluster-node-group",
    "eks-node-role",
    "${ClusterName}-node",
    "eks-service-role"
)

foreach ($role in $rolesToDelete) {
    $roleExists = aws iam get-role --role-name $role --region $Region 2>$null
    if ($roleExists) {
        Write-Host "  Deleting IAM role: $role" -ForegroundColor Yellow
        
        # Detach all policies
        $policies = aws iam list-attached-role-policies --role-name $role --region $Region --output json 2>$null | ConvertFrom-Json
        foreach ($policy in $policies.AttachedPolicies) {
            Write-Host "    Detaching policy: $($policy.PolicyName)" -ForegroundColor Gray
            aws iam detach-role-policy --role-name $role --policy-arn $policy.PolicyArn --region $Region 2>$null
        }
        
        # Delete inline policies
        $inlinePolicies = aws iam list-role-policies --role-name $role --region $Region --output json 2>$null | ConvertFrom-Json
        foreach ($inlinePolicy in $inlinePolicies.PolicyNames) {
            Write-Host "    Deleting inline policy: $inlinePolicy" -ForegroundColor Gray
            aws iam delete-role-policy --role-name $role --policy-name $inlinePolicy --region $Region 2>$null
        }
        
        # Delete role
        Write-Host "    Deleting role..." -ForegroundColor Gray
        aws iam delete-role --role-name $role --region $Region 2>$null
        Write-Host "  ✓ IAM role deleted" -ForegroundColor Green
    }
}

# Delete custom IAM policies
Write-Host ""
Write-Host "  Deleting custom IAM policies..." -ForegroundColor Yellow
$policies = aws iam list-policies --scope Local --output json 2>$null | ConvertFrom-Json
foreach ($policy in $policies.Policies) {
    if ($policy.PolicyName -like "*${ClusterName}*" -or $policy.PolicyName -like "*${ProjectName}*" -or $policy.PolicyName -like "*eks*" -or $policy.PolicyName -like "*alb*") {
        Write-Host "    Deleting policy: $($policy.PolicyName)" -ForegroundColor Gray
        
        # Delete all versions except default
        $versions = aws iam list-policy-versions --policy-arn $policy.Arn --output json 2>$null | ConvertFrom-Json
        foreach ($version in $versions.Versions) {
            if (-not $version.IsDefaultVersion) {
                aws iam delete-policy-version --policy-arn $policy.Arn --version-id $version.VersionId --region $Region 2>$null
            }
        }
        
        aws iam delete-policy --policy-arn $policy.Arn --region $Region 2>$null
    }
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  Phase 3: Delete Security Groups" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

$sgs = aws ec2 describe-security-groups --region $Region --filters "Name=group-name,Values=*${ClusterName}*" "Name=group-name,Values=*${ProjectName}*" --output json 2>$null | ConvertFrom-Json

if ($sgs.SecurityGroups) {
    foreach ($sg in $sgs.SecurityGroups) {
        Write-Host "  Found security group: $($sg.GroupName) ($($sg.GroupId))" -ForegroundColor Yellow
        
        # Revoke all ingress rules
        foreach ($rule in $sg.IpPermissions) {
            Write-Host "    Revoking ingress rule..." -ForegroundColor Gray
            aws ec2 revoke-security-group-ingress --group-id $sg.GroupId --region $Region --ip-permissions $rule 2>$null
        }
        
        # Revoke all egress rules
        foreach ($rule in $sg.IpPermissionsEgress) {
            Write-Host "    Revoking egress rule..." -ForegroundColor Gray
            aws ec2 revoke-security-group-egress --group-id $sg.GroupId --region $Region --ip-permissions $rule 2>$null
        }
        
        # Delete security group
        Write-Host "    Deleting security group..." -ForegroundColor Gray
        aws ec2 delete-security-group --group-id $sg.GroupId --region $Region 2>$null
        Write-Host "  ✓ Security group deleted" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  Phase 4: Delete VPC" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# Find VPC by tags
$vpcs = aws ec2 describe-vpcs --region $Region --filters "Name=tag:Name,Values=*${ClusterName}*" "Name=tag:Name,Values=*${ProjectName}*" --output json 2>$null | ConvertFrom-Json

if ($vpcs.Vpcs) {
    foreach ($vpc in $vpcs.Vpcs) {
        Write-Host "  Found VPC: $($vpc.VpcId)" -ForegroundColor Yellow
        
        # Delete Load Balancers first
        $lbs = aws elbv2 describe-load-balancers --region $Region --output json 2>$null | ConvertFrom-Json
        if ($lbs.LoadBalancers) {
            foreach ($lb in $lbs.LoadBalancers) {
                if ($lb.VpcId -eq $vpc.VpcId) {
                    Write-Host "    Deleting Load Balancer: $($lb.LoadBalancerArn)" -ForegroundColor Yellow
                    aws elbv2 delete-load-balancer --load-balancer-arn $lb.LoadBalancerArn --region $Region 2>$null
                }
            }
        }
        
        # Delete NAT gateways
        $ngws = aws ec2 describe-nat-gateways --region $Region --filter "Name=vpc-id,Values=$($vpc.VpcId)" --output json 2>$null | ConvertFrom-Json
        if ($ngws.NatGateways) {
            foreach ($ngw in $ngws.NatGateways) {
                Write-Host "    Deleting NAT Gateway: $($ngw.NatGatewayId)" -ForegroundColor Yellow
                aws ec2 delete-nat-gateway --nat-gateway-id $ngw.NatGatewayId --region $Region 2>$null
            }
        }
        
        # Delete subnets
        if ($vpc.CidrBlockAssociationSet) {
            $subnets = aws ec2 describe-subnets --region $Region --filters "Name=vpc-id,Values=$($vpc.VpcId)" --output json 2>$null | ConvertFrom-Json
            if ($subnets.Subnets) {
                foreach ($subnet in $subnets.Subnets) {
                    Write-Host "    Deleting Subnet: $($subnet.SubnetId)" -ForegroundColor Yellow
                    aws ec2 delete-subnet --subnet-id $subnet.SubnetId --region $Region 2>$null
                }
            }
        }
        
        # Release Elastic IPs
        $addresses = aws ec2 describe-addresses --region $Region --filters "Name=domain,Values=vpc" --output json 2>$null | ConvertFrom-Json
        if ($addresses.Addresses) {
            foreach ($addr in $addresses.Addresses) {
                if ($addr.NetworkInterfaceVpcId -eq $vpc.VpcId) {
                    Write-Host "    Releasing Elastic IP: $($addr.PublicIp)" -ForegroundColor Yellow
                    aws ec2 release-address --allocation-id $addr.AllocationId --region $Region 2>$null
                }
            }
        }
        
        # Delete VPC
        Write-Host "    Deleting VPC..." -ForegroundColor Yellow
        aws ec2 delete-vpc --vpc-id $vpc.VpcId --region $Region 2>$null
        Write-Host "  ✓ VPC deleted" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  Phase 5: Delete S3 Bucket and DynamoDB" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# Delete S3 bucket
$bucketName = "eks-terraform-state-${Region}"
$bucketExists = aws s3 ls $bucketName --region $Region 2>$null
if ($bucketExists) {
    Write-Host "  Deleting S3 bucket: $bucketName" -ForegroundColor Yellow
    
    # Empty bucket first
    aws s3 rm s3://$bucketName --recursive --region $Region 2>$null
    
    # Delete bucket
    aws s3 rb s3://$bucketName --region $Region 2>$null
    Write-Host "  ✓ S3 bucket deleted" -ForegroundColor Green
} else {
    Write-Host "  ✓ S3 bucket not found" -ForegroundColor Gray
}

# Delete DynamoDB table
$tableName = "eks-terraform-locks"
$tableExists = aws dynamodb describe-table --table-name $tableName --region $Region 2>$null
if ($tableExists) {
    Write-Host "  Deleting DynamoDB table: $tableName" -ForegroundColor Yellow
    aws dynamodb delete-table --table-name $tableName --region $Region 2>$null
    Write-Host "  ✓ DynamoDB table deleted" -ForegroundColor Green
} else {
    Write-Host "  ✓ DynamoDB table not found" -ForegroundColor Gray
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  ✅ Cleanup Complete!" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "All EKS resources have been deleted from AWS." -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Verify resources deleted in AWS Console" -ForegroundColor Gray
Write-Host "  2. The Terraform state files are still in the infra/environments/prod/ folder" -ForegroundColor Gray
Write-Host "  3. To redeploy: Run ..\..\..\scripts\start-cluster.ps1" -ForegroundColor Gray

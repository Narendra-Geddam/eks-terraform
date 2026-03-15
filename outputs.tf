output "aws_account_id" {
  description = "AWS account where infrastructure is deployed."
  value       = data.aws_caller_identity.current.account_id
}

output "region" {
  description = "Deployment AWS region."
  value       = var.aws_region
}

output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS API endpoint."
  value       = module.eks.cluster_endpoint
}

output "cluster_version" {
  description = "EKS Kubernetes version."
  value       = module.eks.cluster_version
}

output "vpc_id" {
  description = "VPC ID used by the EKS cluster."
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs used by worker nodes."
  value       = module.vpc.private_subnets
}

output "public_subnet_ids" {
  description = "Public subnet IDs."
  value       = module.vpc.public_subnets
}

output "cluster_oidc_provider_url" {
  description = "OIDC provider URL for IRSA (IAM Roles for Service Accounts)."
  value       = module.eks.oidc_provider
}

output "cluster_addons" {
  description = "EKS cluster add-ons status."
  value       = module.eks.cluster_addons
}

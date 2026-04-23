provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

data "aws_eks_cluster" "cluster" {
  count = var.enable_kubernetes_resources ? 1 : 0
  name  = var.cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  count = var.enable_kubernetes_resources ? 1 : 0
  name  = var.cluster_name
}

locals {
  kubernetes_host                   = var.enable_kubernetes_resources ? data.aws_eks_cluster.cluster[0].endpoint : "https://127.0.0.1"
  kubernetes_cluster_ca_certificate = var.enable_kubernetes_resources ? base64decode(data.aws_eks_cluster.cluster[0].certificate_authority[0].data) : null
  kubernetes_token                  = var.enable_kubernetes_resources ? data.aws_eks_cluster_auth.cluster[0].token : null
}

# Kubernetes provider - configured against the live cluster only when enabled.
provider "kubernetes" {
  host                   = local.kubernetes_host
  cluster_ca_certificate = local.kubernetes_cluster_ca_certificate
  token                  = local.kubernetes_token
}

# Helm provider - for deploying ALB controller when Kubernetes resources are enabled.
provider "helm" {
  kubernetes {
    host                   = local.kubernetes_host
    cluster_ca_certificate = local.kubernetes_cluster_ca_certificate
    token                  = local.kubernetes_token
  }
}

data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }

  # Remote state backend - S3 with DynamoDB for state locking
  # Uncomment after running bootstrap-state-storage.tf
  # backend "s3" {
  #   bucket         = "eks-terraform-state-ap-south-1"
  #   key            = "eks/terraform.tfstate"
  #   region         = "ap-south-1"
  #   dynamodb_table = "eks-terraform-locks"
  #   encrypt        = true
  # }
}

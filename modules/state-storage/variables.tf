variable "bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  type        = string
}

variable "dynamodb_table" {
  description = "Name of the DynamoDB table for state locking"
  type        = string
  default     = "terraform-locks"
}

variable "region" {
  description = "AWS region for the bucket"
  type        = string
}

variable "project_name" {
  description = "Project name for tags"
  type        = string
  default     = "eks-demo"
}

variable "environment" {
  description = "Environment for tags"
  type        = string
  default     = "dev"
}
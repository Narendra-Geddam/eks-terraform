# Bootstrap: S3 Bucket and DynamoDB Table for Remote State
#
# IMPORTANT: This file creates the backend infrastructure.
# Run this ONCE with local state before enabling the remote backend:
#
#   1. terraform init                    # Initialize providers
#   2. terraform apply -target=module.state_storage   # Create bucket + DynamoDB
#   3. terraform init -migrate-state    # Migrate state to remote backend
#   4. terraform apply                   # Continue with normal operations
#
# After migration, you can optionally remove this file or keep it for reference.

# Note: Using a separate module call to keep resource management clean
module "state_storage" {
  source = "./modules/state-storage"

  bucket_name      = "eks-terraform-state-ap-south-1"
  dynamodb_table   = "eks-terraform-locks"
  region           = "ap-south-1"
}

# Local output to verify resources were created
output "state_bucket_arn" {
  value       = module.state_storage.bucket_arn
  description = "ARN of the S3 bucket for Terraform state"
}

output "locks_table_arn" {
  value       = module.state_storage.dynamodb_table_arn
  description = "ARN of the DynamoDB table for state locking"
}
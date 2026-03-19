# Security Group Rules for ALB Ingress
# 
# This file creates security group rules that allow traffic to ALB listeners
# The ALB security group is created dynamically by the AWS Load Balancer Controller
# We need to add ingress rules to allow HTTP (80) and HTTPS (443) traffic

locals {
  alb_security_group_tags = {
    "ingress.k8s.aws/resource" = "ManagedLBSecurityGroup"
    "elbv2.k8s.aws/cluster"    = var.cluster_name
  }
}

# Find the ALB security group (created by ALB Controller)
data "aws_security_groups" "alb" {
  filter {
    name   = "tag:ingress.k8s.aws/resource"
    values = ["ManagedLBSecurityGroup"]
  }

  filter {
    name   = "tag:elbv2.k8s.aws/cluster"
    values = [var.cluster_name]
  }
}

# Find node security groups for the cluster
data "aws_security_groups" "nodes" {
  filter {
    name   = "tag:karpenter.sh/discovery"
    values = [var.cluster_name]
  }
}

# Allow HTTP traffic (port 80) to ALB from anywhere
resource "aws_security_group_rule" "alb_http" {
  count = length(data.aws_security_groups.alb.ids) > 0 ? 1 : 0

  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = data.aws_security_groups.alb.ids[0]
  description       = "Allow HTTP traffic to ALB"
}

# Allow HTTPS traffic (port 443) to ALB from anywhere
resource "aws_security_group_rule" "alb_https" {
  count = length(data.aws_security_groups.alb.ids) > 0 ? 1 : 0

  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = data.aws_security_groups.alb.ids[0]
  description       = "Allow HTTPS traffic to ALB"
}

# Allow ALB to send traffic to nodes on port 80 (HTTP)
resource "aws_security_group_rule" "alb_to_nodes_http" {
  count = (length(data.aws_security_groups.alb.ids) > 0 && length(data.aws_security_groups.nodes.ids) > 0) ? 1 : 0

  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  security_group_id        = data.aws_security_groups.nodes.ids[0]
  source_security_group_id = data.aws_security_groups.alb.ids[0]
  description              = "Allow ALB to send HTTP traffic to nodes"
}

# Allow ALB to send traffic to nodes on port 443 (HTTPS)
resource "aws_security_group_rule" "alb_to_nodes_https" {
  count = (length(data.aws_security_groups.alb.ids) > 0 && length(data.aws_security_groups.nodes.ids) > 0) ? 1 : 0

  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = data.aws_security_groups.nodes.ids[0]
  source_security_group_id = data.aws_security_groups.alb.ids[0]
  description              = "Allow ALB to send HTTPS traffic to nodes"
}

output "alb_security_group_id" {
  description = "Security group ID of the ALB"
  value       = length(data.aws_security_groups.alb.ids) > 0 ? data.aws_security_groups.alb.ids[0] : null
}

output "node_security_group_id" {
  description = "Security group ID of the EKS nodes"
  value       = length(data.aws_security_groups.nodes.ids) > 0 ? data.aws_security_groups.nodes.ids[0] : null
}

output "alb_http_rule_id" {
  description = "Security group rule ID for HTTP"
  value       = try(aws_security_group_rule.alb_http[0].id, null)
}

output "alb_https_rule_id" {
  description = "Security group rule ID for HTTPS"
  value       = try(aws_security_group_rule.alb_https[0].id, null)
}

output "alb_to_nodes_http_rule_id" {
  description = "Security group rule ID for ALB to nodes HTTP"
  value       = try(aws_security_group_rule.alb_to_nodes_http[0].id, null)
}

output "alb_to_nodes_https_rule_id" {
  description = "Security group rule ID for ALB to nodes HTTPS"
  value       = try(aws_security_group_rule.alb_to_nodes_https[0].id, null)
}

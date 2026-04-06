# ──────────────────────────────────────────
# VPC
# ──────────────────────────────────────────
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "nat_gateway_ips" {
  description = "NAT Gateway public IPs"
  value       = module.vpc.nat_gateway_ips
}

# ──────────────────────────────────────────
# Security Groups
# ──────────────────────────────────────────
output "alb_sg_id" {
  description = "ALB Security Group ID"
  value       = module.security.alb_sg_id
}

output "eks_node_sg_id" {
  description = "EKS Node Security Group ID"
  value       = module.security.eks_node_sg_id
}

output "database_sg_id" {
  description = "Database Security Group ID"
  value       = module.security.database_sg_id
}

# ──────────────────────────────────────────
# IAM
# ──────────────────────────────────────────
output "eks_cluster_role_arn" {
  description = "EKS Cluster IAM Role ARN"
  value       = module.iam.eks_cluster_role_arn
}

output "eks_node_role_arn" {
  description = "EKS Node IAM Role ARN"
  value       = module.iam.eks_node_role_arn
}

output "github_actions_role_arn" {
  description = "IAM Role ARN cho GitHub Actions — dùng trong workflow"
  value       = module.iam.github_actions_role_arn
}

# ──────────────────────────────────────────
# ECR
# ──────────────────────────────────────────
output "ecr_repository_urls" {
  description = "Map tên service → ECR repository URL"
  value       = module.ecr.repository_urls
}

# ──────────────────────────────────────────
# EKS
# ──────────────────────────────────────────
output "cluster_name" {
  description = "EKS Cluster name — dùng trong kubeconfig và GitHub Actions"
  value       = module.eks_cluster.cluster_name
}

output "cluster_endpoint" {
  description = "EKS Cluster API endpoint"
  value       = module.eks_cluster.cluster_endpoint
}

output "cluster_ca" {
  description = "EKS Cluster certificate authority data"
  value       = module.eks_cluster.cluster_ca
  sensitive   = true
}

output "cluster_version" {
  description = "Kubernetes version đang chạy"
  value       = module.eks_cluster.cluster_version
}

output "node_group_name" {
  description = "EKS Node Group name"
  value       = module.eks_node.node_group_name
}
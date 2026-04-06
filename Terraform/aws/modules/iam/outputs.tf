output "eks_cluster_role_arn" {
  value       = aws_iam_role.eks_cluster_role.arn
}

output "eks_cluster_role_name" {
  value       = aws_iam_role.eks_cluster_role.name
}

output "eks_node_role_arn" {
  value       = aws_iam_role.eks_node_role.arn
}

output "eks_node_role_name" {
  value       = aws_iam_role.eks_node_role.name
}
output "github_actions_role_arn" {
  value       = aws_iam_role.github_actions.arn
  description = "ARN cho GitHub Actions OIDC assume role"
}
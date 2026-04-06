# KMS key for encrypting EKS secrets (etcd at rest)
resource "aws_kms_key" "eks_secrets" {
  description             = "KMS key for EKS secrets encryption - ${var.name_project}"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = {
    Name        = "${var.name_project}-eks-secrets-key"
    Environment = var.Environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_kms_alias" "eks_secrets" {
  name          = "alias/${var.name_project}-eks-secrets"
  target_key_id = aws_kms_key.eks_secrets.key_id
}

# CloudWatch Log Group for EKS control plane logs
resource "aws_cloudwatch_log_group" "eks_cluster" {
  name              = "/aws/eks/${var.name_project}-cluster/cluster"
  retention_in_days = 30

  tags = {
    Name        = "${var.name_project}-eks-logs"
    Environment = var.Environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_eks_cluster" "cluster" {
  name     = "${var.name_project}-cluster"
  role_arn = var.eks_cluster_role_arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = var.private_subnets
    security_group_ids      = [var.eks_node_sg_id]
    endpoint_private_access = true
    # Set to false by default; enable only if external kubectl access is required
    endpoint_public_access  = var.endpoint_public_access
  }

  # Encrypt Kubernetes secrets (etcd) using KMS
  encryption_config {
    provider {
      key_arn = aws_kms_key.eks_secrets.arn
    }
    resources = ["secrets"]
  }

  # Enable all control plane log types
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  # Ensure log group exists before cluster tries to write logs
  depends_on = [aws_cloudwatch_log_group.eks_cluster]

  tags = {
    Name        = "${var.name_project}-cluster"
    Environment = var.Environment
    ManagedBy   = "Terraform"
  }
}

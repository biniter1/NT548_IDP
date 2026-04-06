# ──────────────────────────────────────────
# General
# ──────────────────────────────────────────
variable "aws_region" {
  type        = string
  description = "AWS region"
}

variable "name_project" {
  type        = string
  description = "Tên project, dùng để prefix tên resources"
}

variable "Environment" {
  type        = string
  description = "Môi trường triển khai"
}

# ──────────────────────────────────────────
# VPC
# ──────────────────────────────────────────
variable "cidr_vpc" {
  type        = string
  description = "CIDR block của VPC"
}

variable "azs" {
  type        = list(string)
  description = "Danh sách Availability Zones"
}

variable "public_subnets" {
  type        = list(string)
  description = "CIDR blocks cho public subnets"
}

variable "private_subnets" {
  type        = list(string)
  description = "CIDR blocks cho private subnets"
}

# ──────────────────────────────────────────
# EKS
# ──────────────────────────────────────────
variable "kubernetes_version" {
  type        = string
  description = "Kubernetes version cho EKS cluster"
  default     = "1.31"
}

variable "instance_types" {
  type        = list(string)
  description = "EC2 instance types cho worker nodes"
  default     = ["t3.large"]
}

variable "desired_size" {
  type        = number
  description = "Số node mong muốn"
  default     = 2
}

variable "min_size" {
  type        = number
  description = "Số node tối thiểu"
  default     = 2
}

variable "max_size" {
  type        = number
  description = "Số node tối đa"
  default     = 4
}

# ──────────────────────────────────────────
# GitHub OIDC
# ──────────────────────────────────────────
variable "github_repo" {
  type        = string
  description = "GitHub repo theo format org/repo-name, dùng cho OIDC trust policy"
}
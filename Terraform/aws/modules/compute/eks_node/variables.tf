variable "Environment" {
  type        = string
  description = "Environment"
}

variable "eks_cluster_name" {
  type        = string
  description = "EKS Cluster name"
}

variable "eks_node_role_arn" {
  type        = string
  description = "ARN of the EKS node IAM role"
}

variable "eks_node_role_name" {
  type        = string
  description = "Name of the EKS node IAM role"
}

variable "private_subnets" {
  type        = list(string)
  description = "Private subnet IDs for worker nodes"
}

variable "instance_types" {
  type        = list(string)
  description = "EC2 instance types for worker nodes"
  default     = ["t3.large"]
}

variable "desired_size" {
  type        = number
  description = "Desired number of worker nodes"
  default     = 2
}

variable "min_size" {
  type        = number
  description = "Minimum number of worker nodes"
  default     = 2
}

variable "max_size" {
  type        = number
  description = "Maximum number of worker nodes"
  default     = 4
}

variable "disk_size" {
  type        = number
  description = "EBS volume size in GB for each worker node"
  default     = 50
}

variable "capacity_type" {
  type        = string
  description = "Capacity type for worker nodes: ON_DEMAND or SPOT"
  default     = "ON_DEMAND"

  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.capacity_type)
    error_message = "capacity_type must be ON_DEMAND or SPOT."
  }
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.39.0"
    }
  }
}

provider "aws" {
  region = "ap-southeast-1"
}

module "vpc"{
  source = "../../modules/vpc"
  name_project    = var.name_project
  Environment     = var.Environment
  cidr_vpc        = var.cidr_vpc
  azs             = var.azs
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets
}
module "iam" {
  source = "../../modules/iam"
  name_project = var.name_project
  github_repo  = var.github_repo
}
module "security" {
  source = "../../modules/security"
  vpc_id = module.vpc.vpc_id
}
module "ecr" {
  source               = "../../modules/ecr"
  image_tag_mutability = "IMMUTABLE"
}
module "eks_cluster" {
  source = "../../modules/compute/eks_cluster"
  name_project         = var.name_project
  Environment          = var.Environment
  kubernetes_version   = var.kubernetes_version
  private_subnets      = module.vpc.private_subnet_ids
  eks_cluster_role_arn = module.iam.eks_cluster_role_arn
  eks_node_sg_id       = module.security.eks_node_sg_id
}
module "eks_node" {
  source = "../../modules/compute/eks_node"
  Environment       = var.Environment
  eks_cluster_name  = module.eks_cluster.cluster_name
  eks_node_role_arn = module.iam.eks_node_role_arn
  eks_node_role_name = module.iam.eks_node_role_name
  private_subnets   = module.vpc.private_subnet_ids
  instance_types    = var.instance_types
  desired_size      = var.desired_size
  min_size          = var.min_size
  max_size          = var.max_size
}
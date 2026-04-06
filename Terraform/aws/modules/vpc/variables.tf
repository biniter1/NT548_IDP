# Project
variable "name_project" {
  type        = string
  description = "Name of the project, used to prefix resource names"
}

variable "Environment" {
  type        = string
  description = "Deployment environment (dev, staging, prod)"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.Environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}


# VPC
variable "cidr_vpc" {
  type        = string
  description = "CIDR block for the VPC"
}
variable "azs" {
  type        = list(string)
  description = "List of Availability Zones"
}
variable "public_subnets" {
  type        = list(string)
  description = "CIDR blocks for public subnets"
}
variable "private_subnets" {
  type        = list(string)
  description = "CIDR blocks for private subnets"
}
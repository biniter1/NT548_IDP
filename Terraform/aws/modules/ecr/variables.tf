variable "image_tag_mutability" {
  type        = string
  description = "Image tag mutability: IMMUTABLE (recommended for prod) or MUTABLE"
  default     = "IMMUTABLE"

  validation {
    condition     = contains(["IMMUTABLE", "MUTABLE"], var.image_tag_mutability)
    error_message = "image_tag_mutability must be IMMUTABLE or MUTABLE."
  }
}
variable "github_token" {
  type      = string
  sensitive = true
}

variable "github_owner" {
  type        = string
  description = "GitHub username hoặc org name"
}

variable "repo_name" {
  type    = string
  default = "devops-project"
}

variable "team_members" {
  type        = list(string)
  description = "GitHub usernames của các thành viên"
  default     = []
}
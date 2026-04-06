# ============================================================
# CÁCH DÙNG
# 1. Tạo GitHub PAT: Settings → Developer settings → PAT (classic)
#    Scope cần: repo, delete_repo, workflow, admin:org (nếu dùng org)
# 2. Tạo file terraform.tfvars (không commit file này):
#    github_token = "ghp_xxxxxxxxxxxx"
#    github_owner = "your-org-or-username"
# 3. terraform init && terraform apply
# ============================================================

terraform {
  required_version = ">= 1.6"
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}

provider "github" {
  token = var.github_token
  owner = var.github_owner
}


# ============================================================
# REPO
# ============================================================

resource "github_repository" "devops_project" {
  name        = var.repo_name
  description = "DevOps đồ án — CI/CD + GitOps + IDP trên Online Boutique"
  visibility  = "private"

  has_issues   = true
  has_projects = true
  has_wiki     = false

  auto_init            = true
  gitignore_template   = "Terraform"
  license_template     = "mit"

  delete_branch_on_merge = true

  allow_squash_merge = true
  allow_merge_commit = false
  allow_rebase_merge = true
}

# ============================================================
# BRANCHES
# ============================================================

resource "github_branch" "develop" {
  repository = github_repository.devops_project.name
  branch     = "develop"
  source_branch = "main"
}

resource "github_branch_default" "default" {
  repository = github_repository.devops_project.name
  branch     = "main"
}

# Branch protection: main
resource "github_branch_protection" "main" {
  repository_id = github_repository.devops_project.node_id
  pattern       = "main"

  required_status_checks {
    strict   = true
    contexts = [] # Thêm tên CI jobs vào đây sau khi có workflow
  }

  required_pull_request_reviews {
    required_approving_review_count = 1
    dismiss_stale_reviews           = true
  }

  enforce_admins          = false
  allows_force_pushes     = false
  allows_deletions        = false
}

# Branch protection: develop
resource "github_branch_protection" "develop" {
  repository_id = github_repository.devops_project.node_id
  pattern       = "develop"

  required_pull_request_reviews {
    required_approving_review_count = 1
    dismiss_stale_reviews           = true
  }

  allows_force_pushes = false
  allows_deletions    = false
}

# ============================================================
# REPO SECRETS (GitHub Actions dùng)
# ============================================================

resource "github_actions_secret" "ghcr_token" {
  repository      = github_repository.devops_project.name
  secret_name     = "GH_PAT"
  plaintext_value = var.github_token
}

# ============================================================
# FOLDER STRUCTURE — tạo bằng .gitkeep files
# ============================================================

locals {
  # Danh sách services của Online Boutique
  services = [
    "frontend",
    "cartservice",
    "checkoutservice",
    "productcatalogservice",
    "currencyservice",
    "paymentservice",
    "emailservice",
    "shippingservice",
    "recommendationservice",
    "adservice",
  ]

  # Tạo path cho từng service
  service_app_paths = {
    for svc in local.services :
    svc => "apps/${svc}/.gitkeep"
  }

  # Các thư mục cố định
  static_paths = {
    "charts"              = "charts/.gitkeep"
    "gitops_apps"         = "gitops/apps/.gitkeep"
    "workflows"           = ".github/workflows/.gitkeep"
    "monitoring_prom"     = "monitoring/prometheus/.gitkeep"
    "monitoring_grafana"  = "monitoring/grafana/.gitkeep"
    "monitoring_loki"     = "monitoring/loki/.gitkeep"
    "catalog"             = "catalog/.gitkeep"
    "templates"           = "templates/.gitkeep"
    "docs"                = "docs/.gitkeep"
  }
}

# Tạo .gitkeep cho thư mục apps/<service>/
resource "github_repository_file" "service_dirs" {
  for_each = local.service_app_paths

  repository          = github_repository.devops_project.name
  branch              = "main"
  file                = each.value
  content             = ""
  commit_message      = "chore: init folder structure for ${each.key}"
  overwrite_on_create = true
}

# Tạo các thư mục cố định
resource "github_repository_file" "static_dirs" {
  for_each = local.static_paths

  repository          = github_repository.devops_project.name
  branch              = "main"
  file                = each.value
  content             = ""
  commit_message      = "chore: init ${each.key} directory"
  overwrite_on_create = true
}

# ============================================================
# FILE MẪU — .gitignore bổ sung
# ============================================================

resource "github_repository_file" "gitignore_extra" {
  repository     = github_repository.devops_project.name
  branch         = "main"
  file           = ".gitignore"
  commit_message = "chore: add project gitignore"
  overwrite_on_create = true

  content = <<-EOT
    # Env files — KHÔNG bao giờ commit
    .env
    *.env
    .env.*

    # Terraform
    .terraform/
    .terraform.lock.hcl
    terraform.tfvars
    *.tfstate
    *.tfstate.backup

    # Backstage
    backstage/node_modules/
    backstage/dist/
    backstage/.cache/

    # Helm
    *.tgz
    charts/*/charts/

    # OS
    .DS_Store
    Thumbs.db

    # IDE
    .idea/
    .vscode/
    *.swp
  EOT
}

# ============================================================
# README
# ============================================================

resource "github_repository_file" "readme" {
  repository          = github_repository.devops_project.name
  branch              = "main"
  file                = "README.md"
  commit_message      = "docs: init README"
  overwrite_on_create = true

  content = <<-EOT
    # DevOps Project — Online Boutique

    Đồ án môn DevOps: xây dựng hệ thống CI/CD + GitOps + IDP cho ứng dụng microservices.

    ## Ứng dụng mẫu
    [Google Online Boutique](https://github.com/GoogleCloudPlatform/microservices-demo) — 10 microservices đa ngôn ngữ.

    ## Kiến trúc
    ```
    GitHub Actions (CI) → GHCR (registry) → ArgoCD (GitOps CD) → Kubernetes (kind)
                                                                 ↑
                                                          Backstage (IDP)
    ```

    ## Cấu trúc repo
    ```
    ├── apps/               # Helm values override cho từng service
    ├── charts/             # Helm chart gốc
    ├── gitops/             # ArgoCD Application manifests
    │   └── apps/
    ├── .github/workflows/  # GitHub Actions pipelines
    ├── monitoring/         # Prometheus, Grafana, Loki configs
    ├── catalog/            # Backstage catalog-info files
    ├── templates/          # Backstage software templates
    └── docs/
    ```

    ## Phase 1 — DevOps Foundation
    - [ ] Kubernetes cluster (kind)
    - [ ] CI pipeline (GitHub Actions + GHCR)
    - [ ] GitOps CD (ArgoCD)
    - [ ] Observability (Prometheus + Grafana + Loki)

    ## Phase 2 — IDP
    - [ ] Backstage Software Catalog
    - [ ] Plugin integrations (ArgoCD, Grafana, GitHub Actions, K8s)
    - [ ] Software Templates (scaffolding)

    ## Setup

    ```bash
    # 1. Tạo cluster
    kind create cluster --config kind-config.yaml

    # 2. Tạo namespaces
    kubectl create namespace boutique
    kubectl create namespace argocd
    kubectl create namespace monitoring

    # 3. Cài ArgoCD
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

    # 4. Apply root app
    kubectl apply -f gitops/root-app.yaml
    ```
  EOT
}

# ============================================================
# VALUES.YAML MẪU cho từng service
# ============================================================

resource "github_repository_file" "service_values" {
  for_each = toset(local.services)

  repository          = github_repository.devops_project.name
  branch              = "main"
  file                = "apps/${each.key}/values.yaml"
  commit_message      = "chore: init values for ${each.key}"
  overwrite_on_create = true

  content = <<-EOT
    # apps/${each.key}/values.yaml
    # File này được CI tự động cập nhật image tag sau mỗi build

    image:
      repository: ghcr.io/${var.github_owner}/${each.key}
      tag: latest
  EOT
}

# ============================================================
# LABELS cho Issues
# ============================================================

locals {
  issue_labels = {
    "phase-1"     = { color = "0075ca", description = "Phase 1: DevOps Foundation" }
    "phase-2"     = { color = "7057ff", description = "Phase 2: IDP" }
    "ci"          = { color = "e4e669", description = "CI Pipeline" }
    "cd"          = { color = "0e8a16", description = "CD / ArgoCD" }
    "k8s"         = { color = "1d76db", description = "Kubernetes" }
    "observability" = { color = "d93f0b", description = "Prometheus / Grafana / Loki" }
    "idp"         = { color = "5319e7", description = "Backstage / IDP" }
    "bug"         = { color = "d73a4a", description = "Bug" }
    "blocked"     = { color = "e11d48", description = "Bị blocked, cần giải quyết" }
  }
}

resource "github_issue_label" "labels" {
  for_each = local.issue_labels

  repository  = github_repository.devops_project.name
  name        = each.key
  color       = each.value.color
  description = each.value.description
}

# ============================================================
# COLLABORATORS (thêm thành viên vào repo)
# ============================================================

resource "github_repository_collaborator" "members" {
  for_each = toset(var.team_members)

  repository = github_repository.devops_project.name
  username   = each.value
  permission = "push"
}

# ============================================================
# OUTPUTS
# ============================================================

output "repo_url" {
  value = github_repository.devops_project.html_url
}

output "repo_clone_url" {
  value = github_repository.devops_project.ssh_clone_url
}

output "repo_full_name" {
  value = github_repository.devops_project.full_name
}
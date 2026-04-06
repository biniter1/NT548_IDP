# IMPLEMENTATION GUIDE — PHASE 1: DevOps Foundation
> Đọc từ đầu đến cuối trước khi làm bất cứ thứ gì. Mỗi section có người phụ trách rõ ràng.

---

## 0. QUY ƯỚC CHUNG (Cả team đọc)

### Cấu trúc repository
```
devops-project/
├── apps/                        # Helm values override cho từng service
│   ├── frontend/
│   │   └── values.yaml
│   ├── cartservice/
│   │   └── values.yaml
│   └── ...
├── charts/                      # Helm chart gốc (copy từ Online Boutique repo)
│   └── onlineboutique/
├── gitops/                      # ArgoCD Application manifests
│   ├── apps/                    # 1 file yaml = 1 ArgoCD Application
│   └── root-app.yaml            # App of Apps entry point
├── .github/
│   └── workflows/               # GitHub Actions pipelines
├── monitoring/                  # Prometheus, Grafana, Loki configs
│   ├── prometheus/
│   ├── grafana/
│   └── loki/
└── docs/
```

### Quy tắc đặt tên
- Branch: `feat/`, `fix/`, `chore/` + mô tả ngắn. VD: `feat/add-argocd-setup`
- Commit: theo Conventional Commits. VD: `feat(ci): add docker build workflow`
- Image tag: `ghcr.io/<org>/<service>:<git-sha-7>`. VD: `ghcr.io/team/frontend:a1b2c3d`
- K8s namespace: `boutique` (app), `argocd` (cd), `monitoring` (obs)

### Phân công
| Thành viên | Phụ trách |
|---|---|
| **M1** | Phần 2 (K8s + Helm) + Phần 4 (ArgoCD) |
| **M2** | Phần 3 (GitHub Actions CI) |
| **M3** | Phần 5 (Observability) |
| **Cả team** | Phần 1 (setup môi trường) + Phần 6 (kiểm thử) |

---

## 1. SETUP MÔI TRƯỜNG (Cả team — Tuần 1, ngày 1)

### 1.1 Cài đặt tools cần thiết

```bash
# macOS (dùng Homebrew)
brew install kubectl helm kind argocd git

# Ubuntu/Debian
curl -sLS https://get.arkade.dev | sudo sh
arkade install kubectl helm kind argocd-cli
```

Kiểm tra version:
```bash
kubectl version --client   # >= 1.28
helm version               # >= 3.12
kind version               # >= 0.20
argocd version --client    # >= 2.9
```

### 1.2 Clone repo Online Boutique về tham khảo

```bash
git clone https://github.com/GoogleCloudPlatform/microservices-demo.git
# Chỉ dùng để tham khảo charts và manifests, KHÔNG làm việc trực tiếp trong này
```

### 1.3 Tạo repo của team

```bash
# Trên GitHub: tạo repo mới tên "devops-project" (private hoặc public)
git clone https://github.com/<your-org>/devops-project.git
cd devops-project

# Tạo cấu trúc thư mục
mkdir -p apps charts gitops/.github/workflows monitoring/{prometheus,grafana,loki} docs

# Copy Helm charts từ repo Online Boutique
cp -r ../microservices-demo/helm-chart/* charts/

git add . && git commit -m "chore: initial repo structure"
git push
```

---

## 2. KUBERNETES CLUSTER & HELM (M1 — Tuần 1)

### 2.1 Tạo cluster với kind

Tạo file `kind-config.yaml` ở root:

```yaml
# kind-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: devops-cluster
nodes:
  - role: control-plane
    kubeadmConfigPatches:
      - |
        kind: InitConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "ingress-ready=true"
    extraPortMappings:
      - containerPort: 80
        hostPort: 80
        protocol: TCP
      - containerPort: 443
        hostPort: 443
        protocol: TCP
  - role: worker
  - role: worker
```

```bash
kind create cluster --config kind-config.yaml
kubectl cluster-info --context kind-devops-cluster

# Tạo các namespaces
kubectl create namespace boutique
kubectl create namespace argocd
kubectl create namespace monitoring
```

### 2.2 Cài NGINX Ingress Controller

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# Đợi ingress controller sẵn sàng
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s
```

### 2.3 Cấu hình Helm values cho Online Boutique

Tạo file `apps/values-override.yaml` — đây là file quan trọng nhất để override images:

```yaml
# apps/values-override.yaml
images:
  repository: ghcr.io/<your-org>   # Thay bằng GitHub org của team
  tag: latest                       # ArgoCD sẽ override cái này

frontend:
  resources:
    requests:
      cpu: 100m
      memory: 64Mi
    limits:
      cpu: 200m
      memory: 128Mi

cartservice:
  resources:
    requests:
      cpu: 100m
      memory: 64Mi
    limits:
      cpu: 200m
      memory: 128Mi

# Thêm tương tự cho các service khác...
# Giữ resources nhỏ vì chạy local
```

### 2.4 Deploy thử Online Boutique bằng Helm (manual, để test)

```bash
helm install boutique ./charts/onlineboutique \
  --namespace boutique \
  -f apps/values-override.yaml

# Kiểm tra pods
kubectl get pods -n boutique

# Đợi tất cả Running
kubectl wait --for=condition=ready pod --all -n boutique --timeout=300s

# Port-forward để test trên browser
kubectl port-forward svc/frontend 8080:80 -n boutique
# Mở http://localhost:8080
```

> **Lưu ý:** Sau bước này ArgoCD sẽ quản lý deploy, KHÔNG dùng `helm install` thủ công nữa.

```bash
# Uninstall sau khi test xong
helm uninstall boutique -n boutique
```

---

## 3. CI PIPELINE — GITHUB ACTIONS (M2 — Tuần 3)

### 3.1 Cấu hình GitHub Container Registry

Vào GitHub repo → Settings → Actions → General:
- Workflow permissions: **Read and write permissions** ✅
- Allow GitHub Actions to create and approve pull requests ✅

Vào GitHub repo → Settings → Secrets and variables → Actions, thêm:
| Secret name | Giá trị |
|---|---|
| `GH_PAT` | Personal Access Token với scope: `repo`, `write:packages` |

### 3.2 Workflow CI chung (reusable)

Tạo file `.github/workflows/ci-service.yml`:

```yaml
# .github/workflows/ci-service.yml
name: CI - Build & Push Service

on:
  workflow_call:
    inputs:
      service_name:
        required: true
        type: string
      service_path:
        required: true
        type: string

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository_owner }}/${{ inputs.service_name }}

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      packages: write

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Log in to GHCR
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          tags: |
            type=sha,prefix=,format=short
            type=raw,value=latest,enable=${{ github.ref == 'refs/heads/main' }}

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: ${{ inputs.service_path }}
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

      - name: Update Helm values (GitOps)
        if: github.ref == 'refs/heads/main'
        run: |
          SHORT_SHA=$(echo ${{ github.sha }} | cut -c1-7)
          
          # Cập nhật image tag trong values file của service
          sed -i "s|tag:.*|tag: ${SHORT_SHA}|g" apps/${{ inputs.service_name }}/values.yaml
          
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add apps/${{ inputs.service_name }}/values.yaml
          git diff --staged --quiet || git commit -m "chore(gitops): update ${{ inputs.service_name }} image to ${SHORT_SHA}"
          git push
```

### 3.3 Trigger CI theo từng service (path-based)

Tạo file `.github/workflows/trigger-frontend.yml`:

```yaml
# .github/workflows/trigger-frontend.yml
name: CI - frontend

on:
  push:
    branches: [main]
    paths:
      - 'src/frontend/**'
      - 'apps/frontend/**'

jobs:
  build:
    uses: ./.github/workflows/ci-service.yml
    with:
      service_name: frontend
      service_path: ./src/frontend
```

> **Làm tương tự cho các services khác:** `trigger-cartservice.yml`, `trigger-checkoutservice.yml`, v.v. Chỉ thay `service_name` và `service_path`.

### 3.4 Cấu trúc values cho từng service

Mỗi service có file values riêng, ArgoCD sẽ đọc file này:

```yaml
# apps/frontend/values.yaml
image:
  repository: ghcr.io/<your-org>/frontend
  tag: latest   # CI tự động update cái này
```

---

## 4. GITOPS CD — ARGOCD (M1 — Tuần 2)

### 4.1 Cài đặt ArgoCD

```bash
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Đợi ArgoCD sẵn sàng
kubectl wait --for=condition=available deployment --all -n argocd --timeout=300s

# Lấy mật khẩu admin mặc định
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo

# Port-forward để vào UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Mở https://localhost:8080 | user: admin | pass: <lấy ở trên>
```

### 4.2 Kết nối ArgoCD với GitHub repo

```bash
# Login CLI
argocd login localhost:8080 --username admin --password <password> --insecure

# Thêm repo (nếu private)
argocd repo add https://github.com/<your-org>/devops-project.git \
  --username <github-username> \
  --password <GH_PAT>
```

### 4.3 App of Apps pattern

Tạo `gitops/root-app.yaml` — đây là "cha" quản lý tất cả apps:

```yaml
# gitops/root-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/<your-org>/devops-project.git
    targetRevision: main
    path: gitops/apps       # Thư mục chứa các Application con
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### 4.4 Tạo ArgoCD Application cho từng service

Tạo file `gitops/apps/frontend.yaml`:

```yaml
# gitops/apps/frontend.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: frontend
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/<your-org>/devops-project.git
    targetRevision: main
    path: charts/onlineboutique
    helm:
      valueFiles:
        - ../../apps/values-override.yaml
        - ../../apps/frontend/values.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: boutique
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

> **Làm tương tự cho các services khác.** Chỉ thay `name` và `valueFiles`.

### 4.5 Apply root app để kích hoạt toàn bộ

```bash
kubectl apply -f gitops/root-app.yaml

# Xem trạng thái
argocd app list
argocd app get root-app
```

### 4.6 Luồng hoạt động sau khi setup xong

```
Developer push code lên main
  → GitHub Actions detect path change
  → Build Docker image → Push lên GHCR
  → Update apps/<service>/values.yaml (commit image tag mới)
  → ArgoCD phát hiện Git thay đổi (polling 3 phút)
  → ArgoCD tự sync → K8s cập nhật Deployment
  → Pod mới chạy với image mới ✅
```

---

## 5. OBSERVABILITY STACK (M3 — Tuần 4)

### 5.1 Cài đặt Prometheus + Grafana qua Helm

```bash
# Thêm Helm repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
```

Tạo file `monitoring/prometheus/values.yaml`:

```yaml
# monitoring/prometheus/values.yaml
prometheus:
  prometheusSpec:
    serviceMonitorSelectorNilUsesHelmValues: false  # Quan trọng: scrape tất cả ServiceMonitor
    retention: 24h
    resources:
      requests:
        cpu: 200m
        memory: 256Mi
      limits:
        cpu: 500m
        memory: 512Mi

grafana:
  enabled: true
  adminPassword: "devops-grafana"   # Đổi lại
  persistence:
    enabled: false   # Local, không cần persist
  dashboardProviders:
    dashboardproviders.yaml:
      apiVersion: 1
      providers:
        - name: default
          folder: DevOps Project
          type: file
          options:
            path: /var/lib/grafana/dashboards/default

alertmanager:
  enabled: false   # Bật sau nếu cần
```

```bash
helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  -f monitoring/prometheus/values.yaml

# Kiểm tra
kubectl get pods -n monitoring
```

### 5.2 Cài đặt Loki + Promtail

Tạo `monitoring/loki/values.yaml`:

```yaml
# monitoring/loki/values.yaml
loki:
  commonConfig:
    replication_factor: 1
  storage:
    type: filesystem
  auth_enabled: false

singleBinary:
  replicas: 1
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 200m
      memory: 256Mi
```

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm install loki grafana/loki-stack \
  --namespace monitoring \
  -f monitoring/loki/values.yaml
```

### 5.3 Cấu hình ServiceMonitor cho Online Boutique

Tạo `monitoring/prometheus/servicemonitor-boutique.yaml`:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: boutique-monitor
  namespace: monitoring
  labels:
    release: monitoring   # Phải match với label của Prometheus
spec:
  namespaceSelector:
    matchNames:
      - boutique
  selector:
    matchLabels:
      app: frontend       # Thêm các services khác tương tự
  endpoints:
    - port: http
      interval: 15s
      path: /metrics
```

```bash
kubectl apply -f monitoring/prometheus/servicemonitor-boutique.yaml
```

### 5.4 Import Grafana dashboards

```bash
# Port-forward Grafana
kubectl port-forward svc/monitoring-grafana 3000:80 -n monitoring
# Mở http://localhost:3000 | user: admin | pass: devops-grafana
```

Trong Grafana UI, import các dashboard IDs sau (Dashboards → Import → nhập ID):
- **315** — Kubernetes cluster overview
- **6417** — Kubernetes pods
- **13639** — Loki logs dashboard

### 5.5 Thêm Loki datasource vào Grafana

Grafana UI → Configuration → Data Sources → Add:
- Type: **Loki**
- URL: `http://loki:3100`
- Save & Test

### 5.6 Tạo alert rule cơ bản

Trong Grafana UI → Alerting → Alert Rules → New Rule:

```
Rule name: Service Down
Condition: absent(up{namespace="boutique"}) == 1
For: 1m
Message: Một service trong namespace boutique đã down
```

---

## 6. KIỂM THỬ END-TO-END (Cả team — Tuần 5)

### 6.1 Checklist Phase 1

```
[ ] kind cluster chạy với 3 nodes (1 control-plane, 2 workers)
[ ] Tất cả pods trong namespace boutique ở trạng thái Running
[ ] Truy cập được frontend qua http://localhost:8080
[ ] Push code vào src/frontend/ → GitHub Actions pipeline chạy thành công
[ ] Image mới xuất hiện trong GHCR
[ ] apps/frontend/values.yaml được cập nhật image tag mới (auto commit)
[ ] ArgoCD tự sync và hiển thị Synced + Healthy
[ ] Pod frontend được rolling update sang image mới
[ ] Prometheus scrape được metrics từ các pods
[ ] Grafana hiển thị dashboard cluster overview
[ ] Logs từ các pods xuất hiện trong Grafana/Loki
```

### 6.2 Test GitOps flow thủ công

```bash
# Giả lập thay đổi nhỏ
echo "# test" >> src/frontend/main.go
git add . && git commit -m "test: trigger CI pipeline"
git push

# Theo dõi pipeline
# → Vào GitHub Actions tab xem workflow chạy

# Sau khi pipeline xong, xem ArgoCD sync
argocd app get frontend --watch

# Xác nhận pod mới
kubectl rollout status deployment/frontend -n boutique
```

### 6.3 Test self-healing

```bash
# Xóa một pod thủ công
kubectl delete pod -l app=frontend -n boutique

# K8s + ArgoCD phải tự tạo lại pod
kubectl get pods -n boutique --watch
```

---

## 7. TROUBLESHOOTING PHỔ BIẾN

| Triệu chứng | Nguyên nhân | Cách fix |
|---|---|---|
| Pod ở trạng thái `Pending` | Không đủ resource | Giảm `resources.requests` trong values.yaml |
| ArgoCD không sync | Git repo chưa được add | `argocd repo add ...` lại |
| CI fail ở bước push image | Thiếu write permission | Kiểm tra Workflow permissions trong repo Settings |
| Prometheus không scrape được | ServiceMonitor label không match | Kiểm tra `release` label |
| Image pull error | Image trên GHCR là private | Tạo imagePullSecret hoặc set GHCR package sang public |

### Tạo imagePullSecret cho GHCR (nếu cần)

```bash
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=<github-username> \
  --docker-password=<GH_PAT> \
  --namespace boutique
```

Thêm vào `apps/values-override.yaml`:
```yaml
imagePullSecrets:
  - name: ghcr-secret
```

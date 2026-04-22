# Phase 1 — DevOps Foundation

Hướng dẫn thiết lập hệ thống từ đầu: K8s cluster → Deploy app → CI/CD → GitOps → Observability.

## Yêu cầu

| Tool | Version | Cài đặt |
|---|---|---|
| Docker Desktop | >= 4.x | https://www.docker.com/products/docker-desktop |
| kind | >= 0.23 | https://kind.sigs.k8s.io/docs/user/quick-start |
| kubectl | >= 1.28 | https://kubernetes.io/docs/tasks/tools |
| Helm | >= 3.14 | https://helm.sh/docs/intro/install |
| ArgoCD CLI | >= 2.9 | https://argo-cd.readthedocs.io/en/stable/cli_installation |
| Git | >= 2.x | https://git-scm.com |

> **Windows:** Cài kind bằng cách tải binary trực tiếp. Chạy tất cả lệnh trong PowerShell. Docker Desktop phải đang chạy trước khi tạo cluster.

---

## 1. Tạo Kubernetes Cluster

```powershell
# Tạo cluster với 1 control-plane + 2 worker nodes
kind create cluster --config k8s/local/kind-config.yaml

# Verify
kubectl get nodes
# Phải thấy 3 nodes đều Ready
```

**`k8s/local/kind-config.yaml`:**
```yaml
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

---

## 2. Tạo Namespaces

```powershell
kubectl create namespace boutique    # Online Boutique app
kubectl create namespace argocd      # ArgoCD CD
kubectl create namespace monitoring  # Observability stack
```

---

## 3. Cài NGINX Ingress Controller

```powershell
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# Đợi controller sẵn sàng
kubectl wait --namespace ingress-nginx `
  --for=condition=ready pod `
  --selector=app.kubernetes.io/component=controller `
  --timeout=120s
```

---

## 4. Deploy Online Boutique bằng Helm

### 4.1 Tạo imagePullSecret (nếu GHCR package private)

```powershell
kubectl create secret docker-registry ghcr-secret `
  --docker-server=ghcr.io `
  --docker-username=<github-username> `
  --docker-password=<GH_PAT> `
  --namespace boutique
```

### 4.2 Deploy

```powershell
helm install boutique helm-chart `
  --namespace boutique `
  -f k8s/local/apps/values-override.yaml `
  --timeout 5m

# Theo dõi pods khởi động
kubectl get pods -n boutique --watch
```

### 4.3 Truy cập frontend

```powershell
kubectl port-forward svc/frontend 8080:80 -n boutique
# Mở http://localhost:8080
```

> **Lưu ý:** Sau khi ArgoCD được setup, KHÔNG dùng `helm install` thủ công nữa. Uninstall trước khi setup ArgoCD:
> ```powershell
> helm uninstall boutique -n boutique
> ```

**`k8s/local/apps/values-override.yaml`:**
```yaml
images:
  repository: ghcr.io/biniter1

loadGenerator:
  create: false

frontend:
  externalService: false

imagePullSecrets:
  - name: ghcr-secret
```

---

## 5. CI Pipeline — GitHub Actions

### 5.1 Cấu hình GitHub repo

1. Vào repo → **Settings → Actions → General**
   - Workflow permissions: **Read and write** ✅
   - Allow GitHub Actions to create PRs ✅

2. Tạo PAT tại **GitHub → Settings → Developer settings → Tokens (classic)**
   - Scope: `repo` ✅ `write:packages` ✅

3. Thêm secret: **Settings → Secrets → Actions → New secret**
   - Name: `GH_PAT` | Value: token vừa tạo

### 5.2 Cấu trúc workflows

```
.github/workflows/
├── ci-service.yml        # Reusable workflow — logic chính
├── ci-frontend.yml       # Trigger khi src/frontend/** thay đổi
├── ci-cartservice.yml
├── ci-checkoutservice.yml
├── ci-productcatalogservice.yml
├── ci-currencyservice.yml
├── ci-paymentservice.yml
├── ci-emailservice.yml
├── ci-shippingservice.yml
├── ci-recommendationservice.yml
└── ci-adservice.yml
```

### 5.3 Luồng CI

```
Push code lên main
  → GitHub Actions detect path thay đổi (src/<service>/.**)
  → Build Docker image
  → Push lên GHCR với tag: latest
```

---

## 6. GitOps CD — ArgoCD

### 6.1 Cài ArgoCD

```powershell
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Đợi sẵn sàng
kubectl wait --for=condition=available deployment --all `
  -n argocd --timeout=300s
```

### 6.2 Lấy password admin

```powershell
kubectl -n argocd get secret argocd-initial-admin-secret `
  -o jsonpath="{.data.password}" | `
  [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_))
```

### 6.3 Truy cập ArgoCD UI

```powershell
# Đổi sang NodePort
kubectl patch svc argocd-server -n argocd `
  -p '{"spec": {"type": "NodePort"}}'

# Xem port
kubectl get svc argocd-server -n argocd
# Mở http://localhost:<nodeport>
# Username: admin | Password: lấy ở bước 6.2

# Windows: tạo port proxy nếu cần
netsh interface portproxy add v4tov4 `
  listenport=8081 listenaddress=127.0.0.1 `
  connectport=<nodeport> connectaddress=127.0.0.1
```

### 6.4 Login ArgoCD CLI

```powershell
argocd login localhost:<nodeport> `
  --username admin `
  --password <password> `
  --insecure
```

### 6.5 Apply App of Apps

```powershell
# Commit và push gitops/ lên GitHub trước
git add gitops/
git commit -m "feat(gitops): add ArgoCD app of apps"
git push

# Apply root app
kubectl apply -f gitops/root-app.yaml

# Verify
kubectl get applications -n argocd
# online-boutique phải Synced + Healthy
```

### 6.6 Cấu trúc GitOps

```
gitops/
├── root-app.yaml              # App cha — quản lý tất cả
└── apps/
    └── online-boutique.yaml   # 1 Application cho toàn bộ chart
```

**`gitops/apps/online-boutique.yaml`:**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: online-boutique
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  sources:
    - repoURL: https://github.com/biniter1/NT548_IDP.git
      targetRevision: main
      path: helm-chart
      helm:
        valueFiles:
          - $values/k8s/local/apps/values-override.yaml
    - repoURL: https://github.com/biniter1/NT548_IDP.git
      targetRevision: main
      ref: values
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

> **Lưu ý:** Chart `onlineboutique` là monolithic — dùng **1 ArgoCD Application** cho toàn bộ, không tạo Application riêng cho từng service.

---

## 7. Observability Stack

### 7.1 Thêm Helm repos

```powershell
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
```

### 7.2 Cài Prometheus + Grafana

```powershell
helm install monitoring prometheus-community/kube-prometheus-stack `
  --namespace monitoring `
  --set grafana.adminPassword=devops2024 `
  --set grafana.service.type=NodePort `
  --set grafana.service.nodePort=32000 `
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false `
  --set alertmanager.enabled=false `
  --timeout 5m

kubectl get pods -n monitoring --watch
# Đợi tất cả Running
```

### 7.3 Cài Loki

```powershell
helm install loki grafana/loki `
  --namespace monitoring `
  --set deploymentMode=SingleBinary `
  --set loki.auth_enabled=false `
  --set loki.commonConfig.replication_factor=1 `
  --set loki.storage.type=filesystem `
  --set loki.useTestSchema=true `
  --set singleBinary.replicas=1 `
  --set read.replicas=0 `
  --set write.replicas=0 `
  --set backend.replicas=0 `
  --set monitoring.selfMonitoring.enabled=false `
  --set monitoring.selfMonitoring.grafanaAgent.installOperator=false `
  --set test.enabled=false `
  --timeout 5m
```

### 7.4 Cài Promtail

```powershell
helm install promtail grafana/promtail `
  --namespace monitoring `
  --set "config.clients[0].url=http://loki.monitoring.svc.cluster.local:3100/loki/api/v1/push" `
  --timeout 3m

# Verify — phải thấy 1 promtail pod per node (DaemonSet)
kubectl get pods -n monitoring | Select-String "promtail"
```

### 7.5 Truy cập Grafana

```powershell
# Lấy NodePort
kubectl get svc monitoring-grafana -n monitoring
# Mở http://localhost:32000
# Username: admin | Password: devops2024
```

### 7.6 Thêm Loki datasource

Vào Grafana UI → **Connections → Data sources → Add → Loki**:
- URL: `http://loki.monitoring.svc.cluster.local:3100`
- Click **Save & test**

### 7.7 Import dashboards

Vào **Dashboards → New → Import**:

| Dashboard ID | Mô tả |
|---|---|
| `15757` | Kubernetes cluster overview |
| `19105` | Kubernetes pods |
| `13639` | Loki logs |

### 7.8 Verify logs từ boutique

Vào **Explore → Loki** → query:
```
{namespace="boutique"}
```
Phải thấy logs real-time từ các services.

---

## 8. Quản lý cluster

```powershell
# Dừng cluster (giữ nguyên data)
docker stop $(docker ps -q --filter "name=devops-cluster")

# Khởi động lại
docker start $(docker ps -aq --filter "name=devops-cluster")

# Xóa hoàn toàn
kind delete cluster --name devops-cluster
```

---

## Checklist Phase 1

```
[ ] kind cluster có 3 nodes đều Ready
[ ] 3 namespaces tồn tại: boutique, argocd, monitoring
[ ] Online Boutique deploy thành công, tất cả pods Running
[ ] Images từ GHCR được pull thành công
[ ] GitHub Actions CI pipeline chạy xanh khi push code
[ ] ArgoCD UI accessible, online-boutique app Synced + Healthy
[ ] ArgoCD tự sync khi values.yaml thay đổi trên Git
[ ] Grafana accessible tại http://localhost:32000
[ ] Prometheus datasource hoạt động
[ ] Loki datasource hoạt động
[ ] Promtail đang chạy, logs từ boutique hiển thị trong Grafana
```

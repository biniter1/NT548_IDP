1. Install kind 

2. Verify tools
```bash
helm verion
kubectl version
kind version
```
3. Kind config to create cluster 
kind-config.yaml
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
    extraMounts:
      - hostPath: /tmp/worker1
        containerPath: /data
  - role: worker
    extraMounts:
      - hostPath: /tmp/worker2
        containerPath: /data
```
```bash
# Tạo cluster
kind create cluster --config kind-config.yaml

# Verify
kubectl cluster-info --context kind-devops-cluster
kubectl get nodes
# Kết quả mong đợi:
# NAME                           STATUS   ROLES           AGE
# devops-cluster-control-plane   Ready    control-plane   1m
# devops-cluster-worker          Ready    <none>          1m
# devops-cluster-worker2         Ready    <none>          1m
```
3. Tạo Namespaces
```bash
kubectl create namespace boutique
kubectl create namespace argocd
kubectl create namespace monitoring

# Verify
kubectl get namespaces
```
4. Cài NGINX Ingress Controller
```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# Đợi controller sẵn sàng (khoảng 1-2 phút)
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s

# Verify
kubectl get pods -n ingress-nginx
```

5. Tạo các thư mục service và file values (chỉ chạy lần đầu tiên khi setup cluster thôi)
```bash
cd scripts
./init-service-values.sh
```
Kết quả — 10 file values:
```
apps/
├── frontend/values.yaml
├── cartservice/values.yaml
├── checkoutservice/values.yaml
├── productcatalogservice/values.yaml
├── currencyservice/values.yaml
├── paymentservice/values.yaml
├── emailservice/values.yaml
├── shippingservice/values.yaml
├── recommendationservice/values.yaml
└── adservice/values.yaml
```
6. Deploy thử bằng Helm (để test chart)

Bước này chỉ để verify chart hoạt động. Sau khi test xong sẽ helm uninstall — ArgoCD sẽ quản lý từ đây.

```bash
# Deploy
cd ..
helm install boutique helm-chart \
  --namespace boutique \
  -f k8s/apps/values-override.yaml \
  --timeout 5m

# Theo dõi pods khởi động
kubectl get pods -n boutique --watch

# Đợi tất cả Running (khoảng 3-5 phút lần đầu pull image)
kubectl wait --for=condition=ready pod \
  --all \
  -n boutique \
  --timeout=300s

# Xem tất cả resources
kubectl get all -n boutique

# Truy cập frontend
kubectl port-forward svc/frontend 8080:80 -n boutique
```
Tạo Ingress cho frontend
k8s/ingress-frontend.yaml
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: frontend-ingress
  namespace: boutique
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: frontend
                port:
                  number: 80
```
```bash
kubectl apply -f k8s/ingress-frontend.yaml

# Test — truy cập thẳng localhost:80
curl -I http://localhost
# HTTP/1.1 200 OK ← thành công

```
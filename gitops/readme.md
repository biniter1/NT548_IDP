1. Cài ArgoCD lên cluster
```bash
# Tạo namespace
kubectl create namespace argocd 

kubectl apply -n argocd -f \
  https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Đợi tất cả pods sẵn sàng (~2 phút)
kubectl wait --for=condition=available deployment --all \
  -n argocd --timeout=300s

# Kiểm tra
kubectl get pods -n argocd
# Mong đợi tất cả 1/1 Running
```


2. Truy cập ArgoCD Ui

```bash
# Port-forward để vào UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Mở https://localhost:8080
# Username: admin
# Password: lấy bằng lệnh bên dưới

kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo
```
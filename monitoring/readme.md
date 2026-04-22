1. Thêm Helm repos
```powershell
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
```

3. Prometheus + Grafana
```powershell
helm install monitoring prometheus-community/kube-prometheus-stack `
  --namespace monitoring `
  --create-namespace `
  -f monitoring/prometheus/values.yaml `
  --timeout 5m

# Đợi pods sẵn sàng
kubectl wait --for=condition=ready pod --all `
  -n monitoring --timeout=300s

# Kiểm tra
kubectl get pods -n monitoring
```

4. Loki + Promtail

```powershell
helm install loki grafana/loki-stack `
  --namespace monitoring `
  -f monitoring/loki/values.yaml `
  --timeout 5m
```
# Kiểm tra
kubectl get pods -n monitoring | Select-String "loki"

5. Thêm Loki datasource vào Grafana
```powershell
kubectl port-forward svc/monitoring-grafana `
  -n monitoring 3000:80
```
Mở http://localhost:3000 — login admin / devops2024
Vào Configuration → Data Sources → Add data source:
  Type: Loki
  URL: http://loki:3100
  Click Save & Test → phải thấy "Data source connected"

6. Tạo ServiceMonitor cho Online Boutique
```powershell
kubectl apply -f monitoring/prometheus/servicemonitor-boutique.yaml
```
7. Import thêm dashboard Loki
Trong Grafana UI → Dashboards → Import:

ID: 13639 → Load → Import (Loki logs dashboard)

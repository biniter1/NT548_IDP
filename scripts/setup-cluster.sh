!#/bin/bash

kind create cluster --config kind-config.yaml

timeout 300s

# Verify
kubectl cluster-info --context kind-devops-cluster
kubectl get nodes

kubectl create namespace boutique
kubectl create namespace argocd
kubectl create namespace monitoring

timeout 5s

kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml


kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s

# Verify
kubectl get pods -n ingress-nginx


# Tạo namespace
kubectl create namespace argocd 

kubectl apply -n argocd -f \
  https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

kubectl wait --for=condition=available deployment --all \
  -n argocd --timeout=300s

kubectl get pods -n argocd

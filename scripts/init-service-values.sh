#!/bin/bash
# scripts/init-service-values.sh

SERVICES=(
  "frontend"
  "cartservice"
  "checkoutservice"
  "productcatalogservice"
  "currencyservice"
  "paymentservice"
  "emailservice"
  "shippingservice"
  "recommendationservice"
  "adservice"
  "shoppingassistantservice"
  "loadgenerator"
)

ORG="biniter1"   # ← Thay tên org

for svc in "${SERVICES[@]}"; do
  mkdir -p "/k8s/apps/${svc}"
  cd ..
  pwd
  cd k8s/apps/${svc}
  cat > "values.yaml" <<EOF

image:
  repository: ghcr.io/${ORG}/${svc}
  tag: latest
EOF
  pwd
  cd ../..
done
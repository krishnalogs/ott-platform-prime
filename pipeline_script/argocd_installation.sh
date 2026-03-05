#!/bin/bash
set -euo pipefail

ARGO_NAMESPACE="argocd"
ARGO_RELEASE="argocd"

echo "================================="
echo " Installing ArgoCD"
echo "================================="

# Add ArgoCD Helm repository
helm repo add argo https://argoproj.github.io/argo-helm || true
helm repo update

# Install or Upgrade ArgoCD
helm upgrade --install $ARGO_RELEASE argo/argo-cd \
  --namespace $ARGO_NAMESPACE \
  --create-namespace \
  --set server.service.type=LoadBalancer \
  --wait \
  --timeout 10m

echo "================================="
echo " ArgoCD Installed Successfully"
echo "================================="

echo "ArgoCD Services:"
kubectl get svc -n $ARGO_NAMESPACE

echo ""
echo "Getting ArgoCD Admin Password..."

kubectl get secret argocd-initial-admin-secret \
  -n $ARGO_NAMESPACE \
  -o jsonpath="{.data.password}" | base64 -d && echo
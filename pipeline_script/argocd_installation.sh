#!/bin/bash
set -e

NAMESPACE="argocd"

echo "Cleaning old ArgoCD installation..."

kubectl delete namespace $NAMESPACE --ignore-not-found
kubectl delete clusterrole argocd-server --ignore-not-found
kubectl delete clusterrolebinding argocd-server --ignore-not-found

echo "Installing ArgoCD..."

helm repo add argo https://argoproj.github.io/argo-helm || true
helm repo update

helm upgrade --install argocd argo/argo-cd \
  --namespace $NAMESPACE \
  --create-namespace \
  --set server.service.type=LoadBalancer \
  --wait

echo "ArgoCD installed successfully"

kubectl get svc -n argocd
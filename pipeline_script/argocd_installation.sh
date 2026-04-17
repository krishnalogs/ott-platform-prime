#!/bin/bash
set -e

NAMESPACE="argocd"

echo "Cleaning old ArgoCD installation..."

kubectl delete namespace $NAMESPACE --ignore-not-found
kubectl delete clusterrole argocd-server --ignore-not-found
kubectl delete clusterrolebinding argocd-server --ignore-not-found

echo "Creating namespace $NAMESPACE..."
kubectl create namespace argocd

echo "Installing ArgoCD..."

kubectl apply -n argocd \
  --server-side \
  --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "ArgoCD installed successfully"

echo "Patching argocd-server service to ELB"

kubectl patch svc argocd-server -n argocd \
  -p '{"spec": {"type": "LoadBalancer"}}'

kubectl get svc -n argocd
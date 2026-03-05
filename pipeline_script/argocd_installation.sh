#!/bin/bash
set -e

# --- Setup Prometheus & Grafana ---
echo ">>> Setting up Prometheus & Grafana..."

# Add Helm repos
helm repo add stable https://charts.helm.sh/stable || true
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || true
helm repo update

# Create namespace for Prometheus
kubectl create namespace prometheus || true

# Install or upgrade Prometheus stack
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack -n prometheus --timeout 15m

# --- Setup ArgoCD ---
echo ">>> Setting up ArgoCD..."

# Create namespace for ArgoCD
kubectl create namespace argocd || true

# Install ArgoCD via Helm (avoids CRD annotation size issue)
helm repo add argo https://argoproj.github.io/argo-helm || true
helm repo update

helm upgrade --install argocd argo/argo-cd -n argocd --timeout 15m

# Patch ArgoCD server service to LoadBalancer
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

echo ">>> Monitoring and ArgoCD setup complete!"
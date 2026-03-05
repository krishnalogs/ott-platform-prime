#!/bin/bash

set -e

NAMESPACE="prometheus"
RELEASE="kube-prometheus-stack"

echo "Adding Helm repository..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || true
helm repo update

echo "Installing / Upgrading Prometheus Stack..."

helm upgrade --install $RELEASE prometheus-community/kube-prometheus-stack \
  --namespace $NAMESPACE \
  --create-namespace \
  --set grafana.service.type=LoadBalancer \
  --set prometheus.service.type=LoadBalancer

echo "Deployment completed"

echo "Checking services..."
kubectl get svc -n $NAMESPACE
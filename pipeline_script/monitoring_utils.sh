#!/bin/bash

set -e

NAMESPACE="prometheus"
RELEASE="kube-prometheus-stack"

echo "Adding Helm repo..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || true
helm repo update

echo "Checking namespace..."

if kubectl get namespace $NAMESPACE >/dev/null 2>&1; then
    echo "Namespace exists - upgrading release"
    helm upgrade $RELEASE prometheus-community/kube-prometheus-stack \
        --namespace $NAMESPACE
else
    echo "Namespace not found - creating and installing"
    kubectl create namespace $NAMESPACE

    helm install $RELEASE prometheus-community/kube-prometheus-stack \
        --namespace $NAMESPACE
fi

echo "Exposing Grafana and Prometheus services..."

kubectl patch svc ${RELEASE}-grafana \
  -n $NAMESPACE \
  -p '{"spec": {"type": "LoadBalancer"}}' || true

kubectl patch svc ${RELEASE}-kube-prometheus-prometheus \
  -n $NAMESPACE \
  -p '{"spec": {"type": "LoadBalancer"}}' || true

echo "Deployment Completed"

kubectl get svc -n $NAMESPACE
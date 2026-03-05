#!/bin/bash

set -e

NAMESPACE="prometheus"
RELEASE_NAME="kube-prometheus-stack"

echo "Adding Helm repositories..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || true
helm repo update

echo "Checking if namespace exists..."
if kubectl get namespace $NAMESPACE > /dev/null 2>&1; then
    echo "Namespace exists. Upgrading Helm release..."
    helm upgrade $RELEASE_NAME prometheus-community/kube-prometheus-stack \
        --namespace $NAMESPACE
else
    echo "Namespace does not exist. Creating namespace and installing Helm chart..."
    kubectl create namespace $NAMESPACE

    helm install $RELEASE_NAME prometheus-community/kube-prometheus-stack \
        --namespace $NAMESPACE
fi

echo "Waiting for services to be created..."
sleep 10

echo "Patching services to LoadBalancer..."

kubectl patch svc ${RELEASE_NAME}-kube-prometheus-prometheus \
  -n $NAMESPACE -p '{"spec": {"type": "LoadBalancer"}}' || true

kubectl patch svc ${RELEASE_NAME}-grafana \
  -n $NAMESPACE -p '{"spec": {"type": "LoadBalancer"}}' || true

echo "Deployment Completed"
kubectl get svc -n $NAMESPACE
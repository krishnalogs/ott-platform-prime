#!/bin/bash

set -e
#!/bin/bash
set -euo pipefail

# =========================
# User variables
# =========================
NAMESPACE="monitoring"
RELEASE_NAME="monitoring"
GRAFANA_ADMIN_PASSWORD="Admin@123456"
STORAGE_CLASS="gp2"   # Change if your cluster uses gp3 or another storage class

# =========================
# Pre-checks
# =========================
echo "Checking kubectl connection..."
kubectl cluster-info >/dev/null 2>&1 || { echo "kubectl is not connected to a cluster"; exit 1; }

echo "Checking Helm..."
helm version >/dev/null 2>&1 || { echo "Helm is not installed"; exit 1; }

# =========================
# Create namespace
# =========================
echo "Creating namespace: ${NAMESPACE}"
kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1 || kubectl create namespace "${NAMESPACE}"

# =========================
# Add Helm repo
# =========================
echo "Adding Prometheus Community Helm repo..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
helm repo update

# =========================
# Create values file
# =========================
cat > monitoring-values.yaml <<EOF
grafana:
  adminPassword: "${GRAFANA_ADMIN_PASSWORD}"
  service:
    type: LoadBalancer
    port: 80
    targetPort: 3000
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-type: external
      service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing
  persistence:
    enabled: true
    type: pvc
    storageClassName: "${STORAGE_CLASS}"
    size: 10Gi

prometheus:
  service:
    type: LoadBalancer
    port: 9090
    targetPort: 9090
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-type: external
      service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing
  prometheusSpec:
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: "${STORAGE_CLASS}"
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 20Gi

alertmanager:
  enabled: true

kube-state-metrics:
  enabled: true

nodeExporter:
  enabled: true
EOF

# =========================
# Install / Upgrade chart
# =========================
echo "Installing kube-prometheus-stack..."
helm upgrade --install "${RELEASE_NAME}" prometheus-community/kube-prometheus-stack \
  --namespace "${NAMESPACE}" \
  -f monitoring-values.yaml

# =========================
# Wait for services
# =========================
echo "Waiting for Grafana service..."
kubectl rollout status deployment/${RELEASE_NAME}-grafana -n "${NAMESPACE}" --timeout=10m || true

echo "Waiting for load balancers to get external hostnames..."
for i in {1..60}; do
  GRAFANA_HOST=$(kubectl get svc "${RELEASE_NAME}-grafana" -n "${NAMESPACE}" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)
  PROM_HOST=$(kubectl get svc "${RELEASE_NAME}-kube-prometheus-prometheus" -n "${NAMESPACE}" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)

  if [[ -n "${GRAFANA_HOST}" && -n "${PROM_HOST}" ]]; then
    break
  fi

  echo "Still waiting... (${i}/60)"
  sleep 10
done

# =========================
# Output results
# =========================
echo ""
echo "======================================="
echo "Installation completed"
echo "======================================="
echo "Namespace        : ${NAMESPACE}"
echo "Release Name     : ${RELEASE_NAME}"
echo "Grafana User     : admin"
echo "Grafana Password : ${GRAFANA_ADMIN_PASSWORD}"
echo ""

echo "Services:"
kubectl get svc -n "${NAMESPACE}"

echo ""

if [[ -n "${GRAFANA_HOST:-}" ]]; then
  echo "Grafana URL    : http://${GRAFANA_HOST}"
else
  echo "Grafana URL    : External hostname not assigned yet"
fi

if [[ -n "${PROM_HOST:-}" ]]; then
  echo "Prometheus URL : http://${PROM_HOST}:9090"
else
  echo "Prometheus URL : External hostname not assigned yet"
fi

echo ""
echo "To troubleshoot:"
echo "kubectl get pods -n ${NAMESPACE}"
echo "kubectl get svc -n ${NAMESPACE}"
echo "kubectl describe svc ${RELEASE_NAME}-grafana -n ${NAMESPACE}"
echo "kubectl describe svc ${RELEASE_NAME}-kube-prometheus-prometheus -n ${NAMESPACE}"
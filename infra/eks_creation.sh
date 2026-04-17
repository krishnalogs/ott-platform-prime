#!/bin/bash
set -euo pipefail

# ==========================================
# User variables
# ==========================================
CLUSTER_NAME="monitoring-eks"
AWS_REGION="ap-southeast-1"
K8S_VERSION="1.31"
NODEGROUP_NAME="ng-1"
INSTANCE_TYPE="t3.medium"
DESIRED_NODES="2"
MIN_NODES="2"
MAX_NODES="3"
VOLUME_SIZE="30"

# ==========================================
# Pre-checks
# ==========================================
echo "Checking required tools..."

command -v aws >/dev/null 2>&1 || { echo "aws CLI is not installed"; exit 1; }
command -v eksctl >/dev/null 2>&1 || { echo "eksctl is not installed"; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "kubectl is not installed"; exit 1; }

echo "Checking AWS credentials..."
aws sts get-caller-identity >/dev/null 2>&1 || { echo "AWS credentials are not configured"; exit 1; }

# ==========================================
# Create EKS cluster config file
# ==========================================
cat > cluster.yaml <<EOF
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: ${CLUSTER_NAME}
  region: ${AWS_REGION}
  version: "${K8S_VERSION}"

iam:
  withOIDC: true

managedNodeGroups:
  - name: ${NODEGROUP_NAME}
    instanceType: ${INSTANCE_TYPE}
    desiredCapacity: ${DESIRED_NODES}
    minSize: ${MIN_NODES}
    maxSize: ${MAX_NODES}
    volumeSize: ${VOLUME_SIZE}
    privateNetworking: false
EOF

echo "Cluster config file created: cluster.yaml"
cat cluster.yaml

# ==========================================
# Create cluster
# ==========================================
echo "Creating EKS cluster: ${CLUSTER_NAME}"
eksctl create cluster -f cluster.yaml

# ==========================================
# Update kubeconfig
# ==========================================
echo "Updating kubeconfig..."
aws eks update-kubeconfig --region "${AWS_REGION}" --name "${CLUSTER_NAME}"

# ==========================================
# Verify cluster
# ==========================================
echo "Verifying cluster..."
kubectl get nodes
kubectl get pods -A

echo ""
echo "======================================"
echo "EKS cluster created successfully"
echo "======================================"
echo "Cluster Name : ${CLUSTER_NAME}"
echo "Region       : ${AWS_REGION}"
echo "K8s Version  : ${K8S_VERSION}"
echo "Node Group   : ${NODEGROUP_NAME}"
echo ""
echo "Useful commands:"
echo "kubectl get nodes"
echo "kubectl get pods -A"
echo "eksctl get cluster --region ${AWS_REGION}"
#!/bin/bash
set -euo pipefail

############################################
# User-configurable variables
############################################
AWS_REGION="ap-southeast-1"
CLUSTER_NAME="prime-ott-eks"
K8S_VERSION="1.31"
NODEGROUP_NAME="prime-ott-ng"
NODE_TYPE="t3.medium"
NODE_COUNT="2"

# NAMESPACE="monitoring"
# RELEASE_NAME="monitoring"

# GRAFANA_ADMIN_PASSWORD="Admin@123456"
# STORAGE_CLASS="gp2"

LBC_POLICY_NAME="AWSLoadBalancerControllerIAMPolicy"
LBC_ROLE_NAME="AmazonEKSLoadBalancerControllerRole"
EBS_ROLE_NAME="AmazonEKS_EBS_CSI_DriverRole"

############################################
# Pre-checks
############################################
echo "Checking required tools..."
for cmd in aws kubectl eksctl helm curl; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERROR: $cmd is not installed"
    exit 1
  fi
done

echo "Checking AWS credentials..."
aws sts get-caller-identity >/dev/null

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

############################################
# 1. Create EKS cluster
############################################
echo "Creating EKS cluster config..."
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
    instanceType: ${NODE_TYPE}
    desiredCapacity: ${NODE_COUNT}
    minSize: 2
    maxSize: 3
    volumeSize: 30
    privateNetworking: false
EOF

echo "Creating EKS cluster..."
eksctl create cluster -f cluster.yaml

# ==========================================
# Update kubeconfig
# ==========================================
echo "Updating kubeconfig..."
aws eks update-kubeconfig --region "${AWS_REGION}" --name "${CLUSTER_NAME}"

echo "Waiting for nodes..."
kubectl get nodes



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


############################################
# 2. Associate OIDC provider
############################################
echo "Associating IAM OIDC provider..."
eksctl utils associate-iam-oidc-provider \
  --region "${AWS_REGION}" \
  --cluster "${CLUSTER_NAME}" \
  --approve

############################################
# 3. Create IAM policy for AWS Load Balancer Controller
############################################
echo "Checking if IAM policy ${LBC_POLICY_NAME} exists..."
LBC_POLICY_ARN=$(aws iam list-policies --scope Local \
  --query "Policies[?PolicyName=='${LBC_POLICY_NAME}'].Arn" \
  --output text)

if [ -z "${LBC_POLICY_ARN}" ] || [ "${LBC_POLICY_ARN}" = "None" ]; then
  echo "Downloading AWS Load Balancer Controller IAM policy..."
  curl -Lo iam-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.14.1/docs/install/iam_policy.json

  echo "Creating IAM policy..."
  LBC_POLICY_ARN=$(aws iam create-policy \
    --policy-name "${LBC_POLICY_NAME}" \
    --policy-document file://iam-policy.json \
    --query 'Policy.Arn' \
    --output text)
else
  echo "IAM policy already exists: ${LBC_POLICY_ARN}"
fi

############################################
# 4. Create IAM service account for AWS Load Balancer Controller
############################################
echo "Creating IAM service account for AWS Load Balancer Controller..."
eksctl create iamserviceaccount \
  --cluster "${CLUSTER_NAME}" \
  --namespace kube-system \
  --name aws-load-balancer-controller \
  --role-name "${LBC_ROLE_NAME}" \
  --attach-policy-arn "${LBC_POLICY_ARN}" \
  --approve \
  --override-existing-serviceaccounts

############################################
# 5. Install AWS Load Balancer Controller
############################################
echo "Getting cluster VPC ID..."
VPC_ID=$(aws eks describe-cluster \
  --name "${CLUSTER_NAME}" \
  --region "${AWS_REGION}" \
  --query "cluster.resourcesVpcConfig.vpcId" \
  --output text)

echo "Adding EKS Helm repo..."
helm repo add eks https://aws.github.io/eks-charts >/dev/null 2>&1 || true
helm repo update

echo "Installing AWS Load Balancer Controller..."
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName="${CLUSTER_NAME}" \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region="${AWS_REGION}" \
  --set vpcId="${VPC_ID}"

echo "Verifying AWS Load Balancer Controller..."
kubectl get deployment -n kube-system aws-load-balancer-controller

############################################
# 6. Create IAM service account for EBS CSI Driver
############################################
echo "Creating IAM service account for EBS CSI driver..."
eksctl create iamserviceaccount \
  --name ebs-csi-controller-sa \
  --namespace kube-system \
  --cluster "${CLUSTER_NAME}" \
  --role-name "${EBS_ROLE_NAME}" \
  --role-only \
  --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
  --approve

############################################
# 7. Install EBS CSI add-on
############################################
echo "Installing EBS CSI add-on..."
eksctl create addon \
  --cluster "${CLUSTER_NAME}" \
  --name aws-ebs-csi-driver \
  --version latest \
  --service-account-role-arn "arn:aws:iam::${ACCOUNT_ID}:role/${EBS_ROLE_NAME}" \
  --force

echo "Checking EBS CSI pods..."
kubectl get pods -n kube-system | grep ebs || true

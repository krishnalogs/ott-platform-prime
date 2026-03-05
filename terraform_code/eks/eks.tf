module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.14.0"
  # ---------------------------------------------------------
  # Cluster Configuration
  # ---------------------------------------------------------
  name    = local.name
  kubernetes_version  = "1.29"

  # ---------------------------------------------------------
  # Networking
  # ---------------------------------------------------------
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnets

  # ---------------------------------------------------------
  # EKS Managed Node Groups
  # ---------------------------------------------------------
  eks_managed_node_groups = {
    ott_node = {

      instance_types = ["t3.medium"]

      min_size     = 2
      max_size     = 4
      desired_size = 2

      capacity_type = "SPOT"

      # Automatically pick correct EKS optimized AMI
      ami_type = "AL2023_x86_64_STANDARD"

      tags = {
        Name = "ott-nodes"
      }
    }
  }

  # ---------------------------------------------------------
  # Global Tags
  # ---------------------------------------------------------
  tags = local.tags
}

# ---------------------------------------------------------
# EKS Add-ons
# ---------------------------------------------------------
resource "aws_eks_addon" "coredns" {
  cluster_name             = module.eks.cluster_name
  addon_name               = "coredns"
  addon_version            = data.aws_eks_addon_version.coredns.version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  preserve                 = true
  tags                     = local.tags
}

resource "aws_eks_addon" "eks_pod_identity_agent" {
  cluster_name             = module.eks.cluster_name
  addon_name               = "eks-pod-identity-agent"
  addon_version            = data.aws_eks_addon_version.eks_pod_identity_agent.version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  preserve                 = true
  tags                     = local.tags
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name             = module.eks.cluster_name
  addon_name               = "kube-proxy"
  addon_version            = data.aws_eks_addon_version.kube_proxy.version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  preserve                 = true
  tags                     = local.tags
}

resource "aws_eks_addon" "vpc_cni" {
  cluster_name             = module.eks.cluster_name
  addon_name               = "vpc-cni"
  addon_version            = data.aws_eks_addon_version.vpc_cni.version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  preserve                 = true
  tags                     = local.tags
}

data "aws_eks_addon_version" "coredns" {
  addon_name           = "coredns"
  kubernetes_version   = module.eks.cluster_version 
  most_recent          = true
}

data "aws_eks_addon_version" "eks_pod_identity_agent" {
  addon_name           = "eks-pod-identity-agent"
  kubernetes_version   = module.eks.cluster_version
  most_recent          = true
}

data "aws_eks_addon_version" "kube_proxy" {
  addon_name           = "kube-proxy"
  kubernetes_version   = module.eks.cluster_version
  most_recent          = true
}

data "aws_eks_addon_version" "vpc_cni" {
  addon_name           = "vpc-cni"
  kubernetes_version   = module.eks.cluster_version
  most_recent          = true
}
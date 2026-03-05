module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.14.0"
  # ---------------------------------------------------------
  # Cluster Configuration
  # ---------------------------------------------------------
  cluster_name                   = local.name
  cluster_version                = "1.29"
  cluster_endpoint_public_access = true

  # ---------------------------------------------------------
  # Cluster Add-ons
  # ---------------------------------------------------------
  cluster_addons = {
    coredns = {
      most_recent = true
    }

    eks-pod-identity-agent = {
      most_recent = true
    }

    kube-proxy = {
      most_recent = true
    }

    vpc-cni = {
      most_recent = true
    }
  }

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
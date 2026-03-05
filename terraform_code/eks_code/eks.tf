module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.14.0"

  cluster_name                   = local.name
  cluster_endpoint_public_access = true

#Add ons to the EKS cluster
  cluster_addons = {
    coredns                = {}
    eks-pod-identity-agent = {
      most_recent = true
    }
    kube-proxy             = {
      most_recent = true
    }
    vpc-cni                = {
      most_recent = true
    }
  }

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets

# EKS Managed Node Group(s)
  eks_managed_node_groups = {
    ott-node = {
      min_size     = 2
      max_size     = 4
      desired_size = 2

      # ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = ["t3.medium"]
      capacity_type  = "SPOT"
      ami_id = "ami-08d59269edddde222"

      tags = {
        ExtraTag = "nodes"
      }
    }
  }

  tags = local.tags
}


locals {
  aws_region       = "us-east-1"
  environment_name = "staging"
  tags = {
    ops_env         = "${local.environment_name}"
    ops_managed_by  = "terraform",
    ops_source_repo = "kubernetes-ops",
    ops_owners      = "devops",
  }
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.37.0"
    }
    random = {
      source = "hashicorp/random"
    }
  }

  backend "remote" {
    # Update to your Terraform Cloud organization
    organization = "klinzdemo"

    workspaces {
      name = "plan-a-job-eks"
    }
  }
}

provider "aws" {
  region = local.aws_region
}

data "terraform_remote_state" "vpc" {
  backend = "remote"
  config = {
    # Update to your Terraform Cloud organization
    organization = "klinzdemo"
    workspaces = {
      name = "plan-a-job"
    }
  }
}

#
# EKS
#
module "eks" {
  source = "github.com/ManagedKube/kubernetes-ops//terraform-modules/aws/eks?ref=v1.0.30"

  aws_region = local.aws_region
  tags       = local.tags

  cluster_name = local.environment_name

  vpc_id         = data.terraform_remote_state.vpc.outputs.vpc_id
  k8s_subnets    = data.terraform_remote_state.vpc.outputs.k8s_subnets
  public_subnets = data.terraform_remote_state.vpc.outputs.private_subnets

  cluster_version = "1.20"

  # public cluster - kubernetes API is publicly accessible
  cluster_endpoint_public_access = true
  cluster_endpoint_public_access_cidrs = [
    "0.0.0.0/0",
    "1.1.1.1/32",
  ]

  # private cluster - kubernetes API is internal the the VPC
  cluster_endpoint_private_access                = true
  cluster_create_endpoint_private_access_sg_rule = true
  cluster_endpoint_private_access_cidrs = [
    "50.0.0.0/8"
  ]

  # Add whatever roles and users you want to access your cluster
  map_users = [
    {
      userarn  = "arn:aws:iam::582024900488:user/spad"
      username = "spad"
      groups   = ["system:masters"]
    },
  ]

  node_groups = {
    ng1 = {
      version          = "1.20"
      disk_size        = 20
      desired_capacity = 2
      max_capacity     = 2
      min_capacity     = 2
      instance_types   = ["t3a.large"]
      additional_tags  = local.tags
      k8s_labels       = {}
    }
  }
}

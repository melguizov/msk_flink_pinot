# Provider definitions (AWS, Kubernetes, etc.)

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.20"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.9"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0"
    }
  }
}

# AWS Provider Configuration

provider "aws" {
  region = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = {
      Project     = "MSK-Flink-Pinot"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# Kubernetes Provider Configuration
# This will be configured after EKS cluster is created
#provider "kubernetes" {
#  host                   = try(module.eks_cluster.cluster_endpoint, "")
#  cluster_ca_certificate = try(base64decode(module.eks_cluster.cluster_certificate_authority_data), "")
#  token                  = try(data.aws_eks_cluster_auth.cluster[0].token, "")
#  
#  # Only configure if cluster exists
#  exec {
#    api_version = "client.authentication.k8s.io/v1beta1"
#    command     = "aws"
#    args        = ["eks", "get-token", "--cluster-name", try(module.eks_cluster.cluster_name, ""), "--profile", var.aws_profile]
#  }
#}

# Helm Provider Configuration
# This will be configured after EKS cluster is created
#provider "helm" {
#  kubernetes = {
#    host                   = try(module.eks_cluster.cluster_endpoint, "")
#    cluster_ca_certificate = try(base64decode(module.eks_cluster.cluster_certificate_authority_data), "")
#    token                  = try(data.aws_eks_cluster_auth.cluster[0].token, "")
#  }
#}

## Data source for EKS cluster authentication
#data "aws_eks_cluster_auth" "cluster" {
#  count = try(module.eks_cluster.cluster_name, "") != "" ? 1 : 0
#  name  = module.eks_cluster.cluster_name
#}

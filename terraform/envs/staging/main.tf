# Staging Environment Configuration
# This file instantiates the root module with staging-specific variables

terraform {
  required_version = ">= 1.0"
  
  backend "s3" {
    # Configure your S3 backend here
    # bucket = "your-terraform-state-bucket"
    # key    = "staging/terraform.tfstate"
    # region = "us-east-1"
  }
}

# Call the root module with staging-specific variables
module "infrastructure" {
  source = "../../"
  
  # VPC Configuration
  vpc_name            = "staging-vpc"
  vpc_cidr            = "10.1.0.0/16"
  vpc_azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  vpc_private_subnets = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
  vpc_public_subnets  = ["10.1.101.0/24", "10.1.102.0/24", "10.1.103.0/24"]
  
  # Kafka Configuration (medium size for staging)
  kafka_cluster_name     = "staging-msk-cluster"
  kafka_broker_nodes     = 3
  kafka_instance_type    = "kafka.m5.large"
  kafka_ebs_volume_size  = 100
  
  # Flink Configuration
  flink_application_name = "staging-flink-app"
  
  # EKS Configuration (medium size for staging)
  eks_cluster_name        = "staging-pinot-cluster"
  eks_node_instance_types = ["t3.medium"]
  eks_node_min_size       = 2
  eks_node_max_size       = 4
  eks_node_desired_size   = 2
  eks_node_disk_size      = 30
  
  # Pinot Configuration (moderate for staging)
  pinot_namespace             = "pinot-staging"
  pinot_zookeeper_replicas    = 3
  pinot_controller_replicas   = 1
  pinot_broker_replicas       = 2
  pinot_server_replicas       = 2
  pinot_minion_replicas       = 1
  
  # Global tags
  tags = {
    Environment = "staging"
    Project     = "msk-flink-pinot"
    ManagedBy   = "terraform"
  }
  
  vpc_tags = {
    Environment = "staging"
    Name        = "staging-vpc"
  }
}

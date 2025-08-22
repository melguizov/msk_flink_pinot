# POC Environment - ULTRA MINIMAL COST CONFIGURATION
# Estimated cost: ~$334/month (~$2.00 for 5 hours)
# This configuration prioritizes cost savings over performance/availability

terraform {
  required_version = ">= 1.0"
  
  backend "s3" {
    # Configure your S3 backend here
    # bucket = "your-terraform-state-bucket"
    # key    = "poc/terraform.tfstate"
    # region = "us-east-1"
  }
}

# Call the root module with ultra-minimal POC configuration
module "infrastructure" {
  source = "../../"
  
  # VPC Configuration - Single AZ deployment
  vpc_name            = "poc-vpc"
  vpc_cidr            = "10.0.0.0/16"
  vpc_azs             = ["us-east-1a"]  # Single AZ = No cross-AZ charges
  vpc_private_subnets = ["10.0.1.0/24"]
  vpc_public_subnets  = ["10.0.101.0/24"]
  
  # Kafka/MSK Configuration - Absolute minimum
  kafka_cluster_name     = "poc-msk"
  kafka_broker_nodes     = 2  # MSK minimum requirement
  kafka_instance_type    = "kafka.t3.small"  # Smallest MSK instance
  kafka_ebs_volume_size  = 10  # Minimum EBS size (1GB per broker minimum)
  kafka_version          = "2.8.1"  # Stable version
  
  # Flink Configuration - Minimal KPU
  flink_application_name = "poc-flink"
  flink_runtime_environment = "FLINK-1_15"
  
  # EKS Configuration - Ultra minimal
  eks_cluster_name        = "poc-cluster"
  eks_cluster_version     = "1.30"
  eks_node_instance_types = ["t3.small"]  # t3.micro might be too small for Pinot
  eks_node_min_size       = 1
  eks_node_max_size       = 1  # No auto-scaling
  eks_node_desired_size   = 1
  eks_node_disk_size      = 10  # Minimal EBS
  
  # Pinot Configuration - Single instance of everything
  pinot_namespace               = "pinot"
  pinot_zookeeper_replicas      = 1  # Single ZK node
  pinot_controller_replicas     = 1
  pinot_broker_replicas         = 1
  pinot_server_replicas         = 1
  pinot_minion_replicas         = 1  # Required for segment management, compaction, etc.
  
  # Ultra-minimal storage
  pinot_zookeeper_storage_size  = "2Gi"
  pinot_controller_storage_size = "2Gi"
  pinot_broker_storage_size     = "2Gi"
  pinot_server_storage_size     = "5Gi"  # Slightly larger for data
  pinot_minion_storage_size     = "2Gi"  # Minimal for minion tasks
  
  # Minimal resource requests
  pinot_zookeeper_resources = {
    requests = {
      cpu    = "100m"
      memory = "256Mi"
    }
    limits = {
      cpu    = "200m"
      memory = "512Mi"
    }
  }
  
  pinot_controller_resources = {
    requests = {
      cpu    = "100m"
      memory = "256Mi"
    }
    limits = {
      cpu    = "200m"
      memory = "512Mi"
    }
  }
  
  pinot_broker_resources = {
    requests = {
      cpu    = "100m"
      memory = "256Mi"
    }
    limits = {
      cpu    = "200m"
      memory = "512Mi"
    }
  }
  
  pinot_server_resources = {
    requests = {
      cpu    = "200m"
      memory = "512Mi"
    }
    limits = {
      cpu    = "500m"
      memory = "1Gi"
    }
  }
  
  pinot_minion_resources = {
    requests = {
      cpu    = "100m"
      memory = "256Mi"
    }
    limits = {
      cpu    = "200m"
      memory = "512Mi"
    }
  }
  
  # POC Tags
  tags = {
    Environment = "poc"
    Project     = "msk-flink-pinot-poc"
    ManagedBy   = "terraform"
    CostCenter  = "poc-minimal"
    Owner       = "data-team"
    Purpose     = "proof-of-concept"
  }
  
  vpc_tags = {
    Environment = "poc"
    Name        = "poc-vpc"
    Purpose     = "poc-networking"
  }
}

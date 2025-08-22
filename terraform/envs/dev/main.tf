# Development Environment Configuration - ENHANCED RESOURCES
# Balanced configuration for development workloads with better performance
# Estimated cost: ~$580/month (~$3.50 for 5 hours)

terraform {
  required_version = ">= 1.0"
  
  backend "s3" {
    # Configure your S3 backend here
    # bucket = "your-terraform-state-bucket"
    # key    = "dev/terraform.tfstate"
    # region = "us-east-1"
  }
}

# Call the root module with development-optimized variables
module "infrastructure" {
  source = "../../"
  
  # VPC Configuration - Multi-AZ for better reliability
  vpc_name            = "dev-vpc"
  vpc_cidr            = "10.1.0.0/16"
  vpc_azs             = ["us-east-1a", "us-east-1b"]  # Multi-AZ for development
  vpc_private_subnets = ["10.1.1.0/24", "10.1.2.0/24"]
  vpc_public_subnets  = ["10.1.101.0/24", "10.1.102.0/24"]
  
  # Kafka Configuration - ENHANCED for development
  kafka_cluster_name     = "dev-msk-cluster"
  kafka_broker_nodes     = 3  # Better availability and throughput
  kafka_instance_type    = "kafka.m5.large"  # Better performance
  kafka_ebs_volume_size  = 100  # More storage for dev datasets
  kafka_version          = "2.8.1"
  
  # Flink Configuration - Enhanced
  flink_application_name = "dev-flink-app"
  flink_runtime_environment = "FLINK-1_15"
  
  # EKS Configuration - ENHANCED for development
  eks_cluster_name        = "dev-pinot-cluster"
  eks_cluster_version     = "1.30"
  eks_node_instance_types = ["t3.medium"]  # Better performance for development
  eks_node_min_size       = 2  # Minimum 2 nodes for better availability
  eks_node_max_size       = 4  # Allow scaling for development loads
  eks_node_desired_size   = 2  # Start with 2 nodes
  eks_node_disk_size      = 50  # More storage per node
  
  # Pinot Configuration - ENHANCED (some components with 2 replicas)
  pinot_namespace             = "pinot-dev"
  pinot_zookeeper_replicas    = 3  # ZK ensemble for better reliability
  pinot_controller_replicas   = 2  # 2 controllers for HA
  pinot_broker_replicas       = 2  # 2 brokers for better query performance
  pinot_server_replicas       = 2  # 2 servers for data distribution
  pinot_minion_replicas       = 1  # 1 minion is sufficient for dev
  
  # Enhanced storage sizes for development datasets
  pinot_zookeeper_storage_size  = "10Gi"  # More ZK storage
  pinot_controller_storage_size = "20Gi"  # Controller metadata
  pinot_broker_storage_size     = "10Gi"  # Broker cache
  pinot_server_storage_size     = "100Gi" # Larger data storage
  pinot_minion_storage_size     = "20Gi"  # Minion working space
  
  # Enhanced resource requests for better performance
  pinot_zookeeper_resources = {
    requests = {
      cpu    = "200m"
      memory = "512Mi"
    }
    limits = {
      cpu    = "500m"
      memory = "1Gi"
    }
  }
  
  pinot_controller_resources = {
    requests = {
      cpu    = "300m"
      memory = "1Gi"
    }
    limits = {
      cpu    = "1000m"
      memory = "2Gi"
    }
  }
  
  pinot_broker_resources = {
    requests = {
      cpu    = "300m"
      memory = "1Gi"
    }
    limits = {
      cpu    = "1000m"
      memory = "2Gi"
    }
  }
  
  pinot_server_resources = {
    requests = {
      cpu    = "500m"
      memory = "2Gi"
    }
    limits = {
      cpu    = "2000m"
      memory = "4Gi"
    }
  }
  
  pinot_minion_resources = {
    requests = {
      cpu    = "200m"
      memory = "512Mi"
    }
    limits = {
      cpu    = "1000m"
      memory = "2Gi"
    }
  }
  
  # Development tags
  tags = {
    Environment = "development"
    Project     = "msk-flink-pinot"
    ManagedBy   = "terraform"
    CostCenter  = "development"
    Team        = "data-engineering"
    Purpose     = "development-workloads"
  }
  
  vpc_tags = {
    Environment = "development"
    Name        = "dev-vpc"
    Purpose     = "development-networking"
  }
}

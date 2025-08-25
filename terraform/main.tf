# VPC Module
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.1.2"

  name = var.vpc_name
  cidr = var.vpc_cidr

  azs             = var.vpc_azs
  private_subnets = var.vpc_private_subnets
  public_subnets  = var.vpc_public_subnets

  enable_nat_gateway     = var.enable_nat_gateway
  single_nat_gateway     = var.single_nat_gateway
  enable_dns_hostnames   = true
  enable_dns_support     = true

  tags = var.vpc_tags
}

# Flink Module (created first to provide EMR security group)
module "flink" {
  source = "./modules/flink"
  
  depends_on = [module.vpc]

  # Temporarily disable Kubernetes resources until authentication is resolved
  enable_kubernetes_resources = false

  # Managed Flink (Kinesis Analytics) variables
  flink_app_name                        = var.flink_application_name
  flink_runtime_environment            = var.flink_runtime_environment
  flink_service_execution_role_arn     = ""  # Will be set by the module itself
  
  # S3 Code Configuration - empty for now since we don't have the JAR yet
  flink_code_bucket_arn = ""
  flink_code_file_key   = ""
  flink_code_content_type = "ZIPFILE"
  
  # VPC Configuration
  flink_subnet_ids         = slice(module.vpc.private_subnets, 0, 2)
  flink_security_group_id  = ""  # Will be set after Kafka module creation
  
  # Optional configurations with defaults
  flink_checkpoint_configuration_type = "DEFAULT"
  flink_monitoring_configuration_type = "DEFAULT"
  
  # VPC and Security Group IDs for security groups
  flink_vpc_id = module.vpc.vpc_id
  msk_sg_id    = ""  # Will be set after Kafka module creation
  
  # EMR-related variables (set to empty/default values since we're using Managed Flink)
  vpc_id                    = module.vpc.vpc_id
  sg_msk_id                = ""  # Will be set after Kafka module creation
  instance_profile_arn     = ""
  service_role_arn         = ""
  autoscaling_role_arn     = ""
  log_uri                  = ""
  subnet_id                = module.vpc.private_subnets[0]
  master_security_group_id = ""
  core_security_group_id   = ""
  msk_arn                  = ""  # Will be set after Kafka module creation
  emr_instance_profile_role_name = ""
  
  tags = var.tags
}

# Bastion Host Module
module "bastion" {
  source = "./modules/bastion"
  
  depends_on = [module.vpc]
  
  bastion_name       = "${var.environment}-msk-bastion"
  instance_type      = "t3.micro"
  public_key         = var.bastion_public_key
  vpc_id             = module.vpc.vpc_id
  public_subnet_id   = module.vpc.public_subnets[0]
  allowed_ssh_cidrs  = var.bastion_allowed_ssh_cidrs
  root_volume_size   = 20
  enable_elastic_ip  = false
  git_repo_url       = "https://github.com/melguizov/msk_flink_pinot.git"  # Update with your repo URL
  
  tags = var.tags
}

# Kafka/MSK Module
module "kafka" {
  source = "./modules/kafka"
  
  depends_on = [module.flink, module.bastion]

  cluster_name               = var.kafka_cluster_name
  kafka_version             = var.kafka_version
  number_of_broker_nodes    = var.kafka_broker_nodes
  broker_instance_type      = var.kafka_instance_type
  broker_ebs_volume_size    = var.kafka_ebs_volume_size
  
  vpc_id                    = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  security_group_ids       = []  # Will be populated by the module's own security group
  sg_emr_id                = module.flink.emr_security_group_id
  bastion_security_group_id = module.bastion.bastion_security_group_id
  
  # Encryption settings
  encryption_in_transit_client_broker = "TLS"
  encryption_in_transit_in_cluster   = true
  encryption_at_rest_kms_key_arn     = null
  
  # Authentication settings
  client_auth_sasl_iam        = true
  client_auth_sasl_scram      = false
  client_auth_tls_enabled     = true
  client_auth_unauthenticated = false
  
  # Monitoring and logging
  enhanced_monitoring         = "DEFAULT"
  log_cloudwatch_enabled     = false
  log_firehose_enabled       = false
  log_s3_enabled             = false
  
  tags = var.tags
}



# EKS Cluster Module
# module "eks_cluster" {
#   source = "./modules/eks-cluster"
# 
#   cluster_name    = var.eks_cluster_name
#   cluster_version = var.eks_cluster_version
#   
#   vpc_id                 = module.vpc.vpc_id
#   subnet_ids             = module.vpc.private_subnets
#   node_group_subnet_ids  = module.vpc.private_subnets
#   
#   cluster_endpoint_public_access       = var.eks_endpoint_public_access
#   cluster_endpoint_private_access      = var.eks_endpoint_private_access
#   cluster_endpoint_public_access_cidrs = var.eks_endpoint_public_access_cidrs
#   
#   node_group_name          = var.eks_node_group_name
#   node_group_instance_types = var.eks_node_instance_types
#   node_group_capacity_type = var.eks_node_capacity_type
#   node_group_min_size      = var.eks_node_min_size
#   node_group_max_size      = var.eks_node_max_size
#   node_group_desired_size  = var.eks_node_desired_size
#   node_group_disk_size     = var.eks_node_disk_size
#   
#   tags = var.tags
# }

# Pinot Module
#module "pinot" {
#  source = "./modules/pinot"
#  
#  depends_on = [module.eks_cluster]
#  
#  enable_pinot_deployment = false  # Temporarily disabled until Kubernetes authentication is resolved
#  namespace = var.pinot_namespace
#  
#  # Zookeeper configuration
#  zookeeper_replicas     = var.pinot_zookeeper_replicas
#  zookeeper_storage_size = var.pinot_zookeeper_storage_size
#  zookeeper_resources    = var.pinot_zookeeper_resources
#  
#  # Pinot configuration
#  pinot_controller_replicas = var.pinot_controller_replicas
#  pinot_broker_replicas     = var.pinot_broker_replicas
#  pinot_server_replicas     = var.pinot_server_replicas
#  pinot_minion_replicas     = var.pinot_minion_replicas
#  
#  pinot_controller_resources = var.pinot_controller_resources
#  pinot_broker_resources     = var.pinot_broker_resources
#  pinot_server_resources     = var.pinot_server_resources
#  pinot_minion_resources     = var.pinot_minion_resources
#  
#  pinot_server_storage_size = var.pinot_server_storage_size
#}

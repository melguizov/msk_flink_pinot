# VPC Outputs
output "vpc_id" {
  description = "ID de la VPC principal"
  value       = module.vpc.vpc_id
}

output "private_subnets" {
  description = "IDs de las subredes privadas"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "IDs de las subredes públicas"
  value       = module.vpc.public_subnets
}

output "nat_gateway_ids" {
  description = "IDs de los NAT Gateways"
  value       = module.vpc.natgw_ids
}

# Kafka/MSK Outputs
output "kafka_cluster_arn" {
  description = "ARN del cluster de Kafka/MSK"
  value       = module.kafka.cluster_arn
}

output "kafka_bootstrap_brokers" {
  description = "Endpoints de bootstrap de Kafka"
  value       = module.kafka.bootstrap_brokers
}

output "kafka_bootstrap_brokers_tls" {
  description = "Endpoints de bootstrap de Kafka con TLS"
  value       = module.kafka.bootstrap_brokers_tls
}

output "kafka_zookeeper_connect_string" {
  description = "String de conexión de Zookeeper"
  value       = module.kafka.zookeeper_connect_string
}

output "kafka_security_group_id" {
  description = "ID del security group de Kafka"
  value       = module.kafka.security_group_id
}

# Flink Outputs
output "flink_application_name" {
  description = "Nombre de la aplicación Flink"
  value       = module.flink.flink_app_name
}

output "flink_application_arn" {
  description = "ARN de la aplicación Flink"
  value       = module.flink.flink_app_arn
}

output "flink_application_status" {
  description = "Estado de la aplicación Flink"
  value       = module.flink.flink_app_status
}

output "flink_application_version" {
  description = "Versión de la aplicación Flink"
  value       = module.flink.flink_app_version
}

output "flink_namespace" {
  description = "Namespace de Kubernetes para Flink"
  value       = module.flink.flink_namespace
}

output "flink_jobmanager_service" {
  description = "Nombre del servicio JobManager"
  value       = module.flink.jobmanager_service_name
}

# # EKS Outputs
# output "eks_cluster_name" {
#   description = "Nombre del cluster EKS"
#   value       = module.eks_cluster.cluster_name
# }
# 
# output "eks_cluster_arn" {
#   description = "ARN del cluster EKS"
#   value       = module.eks_cluster.cluster_arn
# }
# 
# output "eks_cluster_endpoint" {
#   description = "Endpoint del cluster EKS"
#   value       = module.eks_cluster.cluster_endpoint
# }
# 
# output "eks_cluster_version" {
#   description = "Versión del cluster EKS"
#   value       = module.eks_cluster.cluster_version
# }
# 
# output "eks_cluster_security_group_id" {
#   description = "ID del security group del cluster EKS"
#   value       = module.eks_cluster.cluster_security_group_id
# }
# 
# output "eks_node_security_group_id" {
#   description = "ID del security group de los nodos EKS"
#   value       = module.eks_cluster.node_security_group_id
# }
# 
# output "eks_oidc_provider_arn" {
#   description = "ARN del proveedor OIDC de EKS"
#   value       = module.eks_cluster.oidc_provider_arn
# }
# 
# output "eks_aws_load_balancer_controller_role_arn" {
#   description = "ARN del rol IAM para AWS Load Balancer Controller"
#   value       = module.eks_cluster.aws_load_balancer_controller_role_arn
# }
# 
# output "eks_ebs_csi_driver_role_arn" {
#   description = "ARN del rol IAM para EBS CSI Driver"
#   value       = module.eks_cluster.ebs_csi_driver_role_arn
# }
# 
# # Pinot Outputs
# output "pinot_zookeeper_release_name" {
#   description = "Nombre del release de Zookeeper"
#   value       = module.pinot.zookeeper_release_name
# }
# 
# output "pinot_release_name" {
#   description = "Nombre del release de Pinot"
#   value       = module.pinot.pinot_release_name
# }
# 
# output "pinot_controller_service" {
#   description = "Servicio del controlador Pinot"
#   value       = module.pinot.pinot_controller_service
# }
# 
# output "pinot_broker_service" {
#   description = "Servicio del broker Pinot"
#   value       = module.pinot.pinot_broker_service
# }
# 
# output "zookeeper_ensemble" {
#   description = "Ensemble de Zookeeper"
#   value       = module.pinot.zookeeper_ensemble
# }

# Bastion Host Outputs
output "bastion_public_ip" {
  description = "Public IP address of the bastion host"
  value       = module.bastion.bastion_public_ip
}

output "bastion_elastic_ip" {
  description = "Elastic IP address of the bastion host"
  value       = module.bastion.bastion_elastic_ip
}

output "bastion_ssh_command" {
  description = "SSH command to connect to bastion host"
  value       = module.bastion.ssh_command
}

output "bastion_dns_name" {
  description = "Public DNS name of the bastion host"
  value       = module.bastion.bastion_dns_name
}

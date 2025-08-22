output "cluster_name" {
  description = "Nombre del cluster EKS"
  value       = module.eks.cluster_name
}

output "cluster_arn" {
  description = "ARN del cluster EKS"
  value       = module.eks.cluster_arn
}

output "cluster_endpoint" {
  description = "Endpoint del cluster EKS"
  value       = module.eks.cluster_endpoint
}

output "cluster_version" {
  description = "Versión de Kubernetes del cluster"
  value       = module.eks.cluster_version
}

output "cluster_security_group_id" {
  description = "ID del security group del cluster"
  value       = module.eks.cluster_security_group_id
}

output "node_security_group_id" {
  description = "ID del security group de los nodos"
  value       = module.eks.node_security_group_id
}

output "cluster_oidc_issuer_url" {
  description = "URL del OIDC provider del cluster"
  value       = module.eks.cluster_oidc_issuer_url
}

output "oidc_provider_arn" {
  description = "ARN del OIDC provider"
  value       = module.eks.oidc_provider_arn
}

output "aws_load_balancer_controller_role_arn" {
  description = "ARN del rol IAM para AWS Load Balancer Controller"
  value       = module.aws_load_balancer_controller_irsa_role.iam_role_arn
}

output "ebs_csi_driver_role_arn" {
  description = "ARN del rol IAM para EBS CSI Driver"
  value       = module.ebs_csi_irsa_role.iam_role_arn
}

output "cluster_certificate_authority_data" {
  description = "Certificado de autoridad del cluster (base64 encoded)"
  value       = module.eks.cluster_certificate_authority_data
}

output "cluster_primary_security_group_id" {
  description = "ID del security group primario del cluster"
  value       = module.eks.cluster_primary_security_group_id
}

output "node_groups" {
  description = "Información de los node groups"
  value       = module.eks.eks_managed_node_groups
}

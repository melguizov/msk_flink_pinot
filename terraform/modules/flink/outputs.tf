output "flink_app_name" {
  description = "Nombre de la aplicación de Flink (Kinesis Analytics)"
  value       = aws_kinesisanalyticsv2_application.flink.name
}

output "flink_app_arn" {
  description = "ARN de la aplicación de Flink"
  value       = aws_kinesisanalyticsv2_application.flink.arn
}

output "flink_app_status" {
  description = "Estado de la aplicación de Flink"
  value       = aws_kinesisanalyticsv2_application.flink.status
}

output "flink_app_version" {
  description = "Versión de la aplicación de Flink"
  value       = aws_kinesisanalyticsv2_application.flink.version_id
}

# Kubernetes outputs (conditional)
output "flink_namespace" {
  description = "Namespace de Kubernetes para Flink"
  value       = var.enable_kubernetes_resources ? kubernetes_namespace.flink[0].metadata[0].name : null
}

output "jobmanager_service_name" {
  description = "Nombre del servicio JobManager"
  value       = var.enable_kubernetes_resources ? kubernetes_service.jobmanager[0].metadata[0].name : null
}

output "emr_security_group_id" {
  description = "ID del security group de EMR"
  value       = aws_security_group.emr.id
}

output "flink_service_execution_role_arn" {
  description = "ARN del rol de ejecución del servicio Flink"
  value       = aws_iam_role.flink_service_execution_role.arn
}

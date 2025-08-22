output "pinot_release_name" {
  description = "Nombre del release de Helm de Pinot"
  value       = var.enable_pinot_deployment ? helm_release.pinot[0].name : null
}

output "zookeeper_release_name" {
  description = "Nombre del release de Helm de Zookeeper"
  value       = var.enable_pinot_deployment ? helm_release.zookeeper[0].name : null
}

output "pinot_controller_service" {
  description = "Endpoint interno del Controller"
  value       = var.enable_pinot_deployment ? "${helm_release.pinot[0].name}-pinot-controller.${var.namespace}.svc.cluster.local:9000" : null
}

output "pinot_broker_service" {
  description = "Endpoint interno del Broker"
  value       = var.enable_pinot_deployment ? "${helm_release.pinot[0].name}-pinot-broker.${var.namespace}.svc.cluster.local:8099" : null
}

output "zookeeper_ensemble" {
  description = "Lista de endpoints de Zookeeper"
  value = var.enable_pinot_deployment ? [for i in range(var.zookeeper_replicas) : "${helm_release.zookeeper[0].name}-zookeeper-${i}.${helm_release.zookeeper[0].name}-zookeeper-headless.${var.namespace}.svc.cluster.local:2181"] : []
}

output "cluster_arn" {
  description = "ARN del clúster MSK"
  value       = aws_msk_cluster.this.arn
}

output "bootstrap_brokers_tls" {
  description = "Endpoint TLS para clientes Kafka"
  value       = aws_msk_cluster.this.bootstrap_brokers_tls
}

output "bootstrap_brokers_sasl_scram" {
  description = "Endpoint SASL/SCRAM para clientes Kafka"
  value       = aws_msk_cluster.this.bootstrap_brokers_sasl_scram
}

output "bootstrap_brokers_sasl_iam" {
  description = "Endpoint SASL/IAM para clientes Kafka"
  value       = aws_msk_cluster.this.bootstrap_brokers_sasl_iam
}

output "zookeeper_connect_string" {
  description = "Endpoint Zookeeper"
  value       = aws_msk_cluster.this.zookeeper_connect_string
}

output "number_of_broker_nodes" {
  description = "Número de brokers desplegados"
  value       = aws_msk_cluster.this.number_of_broker_nodes
}

output "kafka_version" {
  description = "Versión de Kafka"
  value       = aws_msk_cluster.this.kafka_version
}

output "bootstrap_brokers" {
  description = "Bootstrap brokers endpoint (plaintext)"
  value       = aws_msk_cluster.this.bootstrap_brokers
}

output "security_group_id" {
  description = "ID del security group de MSK"
  value       = aws_security_group.msk.id
}

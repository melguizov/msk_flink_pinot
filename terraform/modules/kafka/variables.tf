variable "cluster_name" {
  description = "Nombre del clúster MSK"
  type        = string
}

variable "sg_msk_name" {
  description = "Nombre del security group para MSK"
  type        = string
  default     = "msk-security-group"
}

variable "vpc_id" {
  description = "ID de la VPC donde crear el SG"
  type        = string
}

variable "sg_emr_id" {
  description = "ID del security group de EMR permitido"
  type        = string
}

variable "sg_msk_tags" {
  description = "Etiquetas para el security group de MSK"
  type        = map(string)
  default     = {}
}

variable "kafka_version" {
  description = "Versión de Apache Kafka"
  type        = string
  default     = "3.4.0"
}

variable "number_of_broker_nodes" {
  description = "Número de brokers para el clúster"
  type        = number
  default     = 3
}

variable "broker_instance_type" {
  description = "Tipo de instancia EC2 para los brokers"
  type        = string
  default     = "kafka.m5.large"
}

variable "broker_ebs_volume_size" {
  description = "Tamaño en GB del volumen EBS para cada broker"
  type        = number
  default     = 100
}

variable "subnet_ids" {
  description = "IDs de las subredes privadas donde desplegar los brokers"
  type        = list(string)
}

variable "security_group_ids" {
  description = "IDs de los grupos de seguridad para los brokers"
  type        = list(string)
}

variable "encryption_in_transit_client_broker" {
  description = "Tipo de cifrado para el tráfico entre clientes y brokers (PLAINTEXT, TLS, TLS_PLAINTEXT)"
  type        = string
  default     = "TLS"
}

variable "encryption_in_transit_in_cluster" {
  description = "Habilita cifrado en tránsito entre brokers"
  type        = bool
  default     = true
}

variable "encryption_at_rest_kms_key_arn" {
  description = "ARN de la clave KMS para cifrado en reposo"
  type        = string
  default     = null
}

variable "enhanced_monitoring" {
  description = "Nivel de monitoreo mejorado (DEFAULT, PER_BROKER, PER_TOPIC_PER_BROKER, PER_TOPIC_PER_PARTITION)"
  type        = string
  default     = "DEFAULT"
}

variable "log_cloudwatch_enabled" {
  description = "Habilita logs en CloudWatch"
  type        = bool
  default     = false
}

variable "log_cloudwatch_log_group" {
  description = "Nombre del log group de CloudWatch"
  type        = string
  default     = null
}

variable "log_firehose_enabled" {
  description = "Habilita logs en Firehose"
  type        = bool
  default     = false
}

variable "log_firehose_delivery_stream" {
  description = "Nombre del delivery stream de Firehose"
  type        = string
  default     = null
}

variable "log_s3_enabled" {
  description = "Habilita logs en S3"
  type        = bool
  default     = false
}

variable "log_s3_bucket" {
  description = "Nombre del bucket S3 para logs"
  type        = string
  default     = null
}

variable "log_s3_prefix" {
  description = "Prefijo para los logs en S3"
  type        = string
  default     = null
}

variable "client_auth_sasl_iam" {
  description = "Habilita autenticación SASL/IAM"
  type        = bool
  default     = false
}

variable "client_auth_sasl_scram" {
  description = "Habilita autenticación SASL/SCRAM"
  type        = bool
  default     = false
}

variable "client_auth_tls_enabled" {
  description = "Habilita autenticación TLS"
  type        = bool
  default     = true
}

variable "client_auth_unauthenticated" {
  description = "Permite clientes sin autenticación (NO recomendado)"
  type        = bool
  default     = false
}

variable "configuration_arn" {
  description = "ARN de la configuración personalizada de MSK"
  type        = string
  default     = null
}

variable "configuration_revision" {
  description = "Revisión de la configuración personalizada"
  type        = number
  default     = null
}

variable "tags" {
  description = "Etiquetas para el clúster MSK"
  type        = map(string)
  default     = {}
}

variable "bastion_security_group_id" {
  description = "Security group ID of the bastion host"
  type        = string
  default     = ""
}

variable "flink_app_name" {
  description = "Nombre de la aplicación de Flink (Kinesis Analytics)"
  type        = string
}

variable "flink_runtime_environment" {
  description = "Runtime de Flink (por ejemplo, FLINK-1_15)"
  type        = string
  default     = "FLINK-1_15"
}

variable "flink_service_execution_role_arn" {
  description = "ARN del rol de ejecución para Kinesis Analytics Flink"
  type        = string
}

variable "flink_code_bucket_arn" {
  description = "ARN del bucket S3 con el código de la aplicación Flink"
  type        = string
}

variable "flink_code_file_key" {
  description = "Key del archivo JAR/ZIP con el código de la aplicación Flink en S3"
  type        = string
}

variable "flink_code_content_type" {
  description = "Tipo de contenido del código de la aplicación (ZIPFILE, PLAINTEXT)"
  type        = string
  default     = "ZIPFILE"
}

variable "flink_subnet_ids" {
  description = "Lista de subnets para la aplicación Flink"
  type        = list(string)
}

variable "flink_security_group_id" {
  description = "Security Group para la aplicación Flink"
  type        = string
}

variable "flink_checkpoint_configuration_type" {
  description = "Tipo de configuración de checkpoint (DEFAULT, CUSTOM)"
  type        = string
  default     = "DEFAULT"
}

variable "flink_monitoring_configuration_type" {
  description = "Tipo de configuración de monitoreo (DEFAULT, CUSTOM)"
  type        = string
  default     = "DEFAULT"
}

variable "flink_sg_name" {
  description = "Nombre del security group para Managed Flink"
  type        = string
  default     = "flink-security-group"
}

variable "flink_vpc_id" {
  description = "ID de la VPC para Managed Flink"
  type        = string
}

variable "msk_sg_id" {
  description = "ID del security group de MSK permitido"
  type        = string
  default     = ""
}

variable "flink_sg_tags" {
  description = "Etiquetas para el security group de Managed Flink"
  type        = map(string)
  default     = {}
}

variable "release_label" {
  description = "Versión de EMR (por ejemplo, emr-7.0.0)"
  type        = string
  default     = "emr-7.0.0"
}

variable "service_role_arn" {
  description = "ARN del rol de servicio EMR"
  type        = string
}

variable "autoscaling_role_arn" {
  description = "ARN del rol de autoscaling EMR"
  type        = string
}

variable "instance_profile_arn" {
  description = "ARN del Instance Profile para EC2"
  type        = string
}

variable "log_uri" {
  description = "Ruta S3 para logs de EMR"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID para el cluster EMR"
  type        = string
}

variable "master_security_group_id" {
  description = "Security Group ID para el master"
  type        = string
}

variable "core_security_group_id" {
  description = "Security Group ID para los core nodes"
  type        = string
}

variable "ec2_key_name" {
  description = "Nombre del key pair EC2 para acceso SSH"
  type        = string
  default     = null
}

variable "master_instance_type" {
  description = "Tipo de instancia para el master"
  type        = string
  default     = "m5.xlarge"
}

variable "core_instance_type" {
  description = "Tipo de instancia para los core nodes"
  type        = string
  default     = "m5.xlarge"
}

variable "core_instance_count" {
  description = "Cantidad de instancias core"
  type        = number
  default     = 2
}

variable "core_ebs_size" {
  description = "Tamaño en GB del volumen EBS para core nodes"
  type        = number
  default     = 100
}

variable "core_ebs_type" {
  description = "Tipo de volumen EBS para core nodes"
  type        = string
  default     = "gp3"
}

variable "flink_configurations_json" {
  description = "Configuración avanzada de Flink en formato JSON para EMR"
  type        = string
  default     = null
}

variable "tags" {
  description = "Etiquetas para el cluster EMR"
  type        = map(string)
  default     = {}
}

variable "sg_emr_name" {
  description = "Nombre del security group para EMR"
  type        = string
  default     = "emr-security-group"
}

variable "flink_properties" {
  description = "Propiedades de configuración para Flink"
  type        = map(string)
  default     = {
    "taskmanager.numberOfTaskSlots" = "1"
    "parallelism.default" = "1"
  }
}

variable "jobmanager_replicas" {
  description = "Número de réplicas del JobManager"
  type        = number
  default     = 1
}

variable "taskmanager_replicas" {
  description = "Número de réplicas del TaskManager"
  type        = number
  default     = 1
}

variable "flink_image" {
  description = "Imagen Docker de Flink"
  type        = string
  default     = "flink:1.15.4"
}

variable "jobmanager_resources_limits" {
  description = "Límites de recursos para JobManager"
  type        = map(string)
  default     = {
    cpu    = "1000m"
    memory = "1Gi"
  }
}

variable "jobmanager_resources_requests" {
  description = "Recursos solicitados para JobManager"
  type        = map(string)
  default     = {
    cpu    = "500m"
    memory = "512Mi"
  }
}

variable "taskmanager_resources_limits" {
  description = "Límites de recursos para TaskManager"
  type        = map(string)
  default     = {
    cpu    = "1000m"
    memory = "1Gi"
  }
}

variable "taskmanager_resources_requests" {
  description = "Recursos solicitados para TaskManager"
  type        = map(string)
  default     = {
    cpu    = "500m"
    memory = "512Mi"
  }
}

variable "vpc_id" {
  description = "ID de la VPC donde crear el SG"
  type        = string
}

variable "sg_msk_id" {
  description = "ID del security group de MSK permitido"
  type        = string
  default     = ""
}

variable "sg_emr_tags" {
  description = "Etiquetas para el security group de EMR"
  type        = map(string)
  default     = {}
}

variable "msk_arn" {
  description = "ARN del cluster MSK para permisos IAM"
  type        = string
}

variable "iam_policy_name" {
  description = "Nombre de la policy IAM para Flink acceso a MSK"
  type        = string
  default     = "FlinkMSKAccess"
}

variable "emr_instance_profile_role_name" {
  description = "Nombre del rol de instancia EMR al que se le adjunta la policy"
  type        = string
}

variable "enable_kubernetes_resources" {
  description = "Enable creation of Kubernetes resources (requires EKS cluster to be ready)"
  type        = bool
  default     = false
}

variable "aws_region"      { default = "us-east-1" }
variable "aws_profile" { default = "wizeline_training" } 

variable "vpc_name" {
  description = "Nombre de la VPC"
  type        = string
  default     = "kafka-flink-pinot-vpc"
}

variable "vpc_cidr" {
  description = "CIDR principal de la VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "vpc_azs" {
  description = "Lista de zonas de disponibilidad"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "vpc_private_subnets" {
  description = "CIDRs para subredes privadas"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "vpc_public_subnets" {
  description = "CIDRs para subredes públicas"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

variable "vpc_tags" {
  description = "Etiquetas para la VPC"
  type        = map(string)
  default     = {}
}

# Global Tags
variable "tags" {
  description = "Etiquetas globales para todos los recursos"
  type        = map(string)
  default     = {}
}

# Kafka/MSK Variables
variable "kafka_cluster_name" {
  description = "Nombre del cluster de Kafka/MSK"
  type        = string
  default     = "msk-cluster"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "kafka_version" {
  description = "Versión de Kafka"
  type        = string
  default     = "2.8.1"
}

variable "kafka_broker_nodes" {
  description = "Número de nodos broker de Kafka"
  type        = number
  default     = 3
}

variable "kafka_instance_type" {
  description = "Tipo de instancia para los brokers de Kafka"
  type        = string
  default     = "kafka.m5.large"
}

variable "kafka_ebs_volume_size" {
  description = "Tamaño del volumen EBS para Kafka (GB)"
  type        = number
  default     = 100
}

variable "kafka_client_authentication" {
  description = "Configuración de autenticación del cliente"
  type = object({
    sasl = optional(object({
      scram = optional(bool, false)
      iam   = optional(bool, false)
    }))
    tls = optional(bool, false)
  })
  default = {
    tls = true
  }
}

variable "kafka_encryption_in_transit" {
  description = "Configuración de cifrado en tránsito"
  type = object({
    client_broker = optional(string, "TLS")
    in_cluster    = optional(bool, true)
  })
  default = {
    client_broker = "TLS"
    in_cluster    = true
  }
}

variable "kafka_encryption_at_rest" {
  description = "Configuración de cifrado en reposo"
  type = object({
    kms_key_id = optional(string)
  })
  default = {}
}

variable "kafka_logging_info" {
  description = "Configuración de logging para Kafka"
  type = object({
    broker_logs = optional(object({
      cloudwatch_logs = optional(object({
        enabled   = optional(bool, false)
        log_group = optional(string)
      }))
      firehose = optional(object({
        enabled         = optional(bool, false)
        delivery_stream = optional(string)
      }))
      s3 = optional(object({
        enabled = optional(bool, false)
        bucket  = optional(string)
        prefix  = optional(string)
      }))
    }))
  })
  default = {
    broker_logs = {
      cloudwatch_logs = {
        enabled = true
      }
    }
  }
}

# Flink Variables
variable "flink_application_name" {
  description = "Nombre de la aplicación Flink"
  type        = string
  default     = "flink-app"
}

variable "flink_runtime_environment" {
  description = "Entorno de ejecución de Flink"
  type        = string
  default     = "FLINK-1_15"
}

variable "flink_service_execution_role" {
  description = "ARN del rol de ejecución del servicio Flink"
  type        = string
  default     = ""
}

variable "flink_application_code_configuration" {
  description = "Configuración del código de la aplicación Flink"
  type = object({
    code_content_type = optional(string, "ZIPFILE")
    s3_content_location = optional(object({
      bucket_arn     = string
      file_key       = string
      object_version = optional(string)
    }))
  })
  default = {
    code_content_type = "ZIPFILE"
  }
}

# EKS Variables
variable "eks_cluster_name" {
  description = "Nombre del cluster EKS"
  type        = string
  default     = "pinot-cluster"
}

variable "eks_cluster_version" {
  description = "Versión de Kubernetes para EKS"
  type        = string
  default     = "1.30"
}

variable "eks_endpoint_public_access" {
  description = "Habilitar acceso público al endpoint del cluster"
  type        = bool
  default     = true
}

variable "eks_endpoint_private_access" {
  description = "Habilitar acceso privado al endpoint del cluster"
  type        = bool
  default     = true
}

variable "eks_endpoint_public_access_cidrs" {
  description = "CIDRs permitidos para acceso público"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "eks_node_group_name" {
  description = "Nombre del grupo de nodos"
  type        = string
  default     = "main"
}

variable "eks_node_instance_types" {
  description = "Tipos de instancia para los nodos"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "eks_node_capacity_type" {
  description = "Tipo de capacidad (ON_DEMAND o SPOT)"
  type        = string
  default     = "ON_DEMAND"
}

variable "eks_node_min_size" {
  description = "Tamaño mínimo del grupo de nodos"
  type        = number
  default     = 1
}

variable "eks_node_max_size" {
  description = "Tamaño máximo del grupo de nodos"
  type        = number
  default     = 3
}

variable "eks_node_desired_size" {
  description = "Tamaño deseado del grupo de nodos"
  type        = number
  default     = 2
  
  validation {
    condition     = var.eks_node_desired_size >= 1
    error_message = "El tamaño deseado debe ser al menos 1 para mantener el cluster operativo."
  }
}

variable "eks_node_disk_size" {
  description = "Tamaño del disco para los nodos (GB)"
  type        = number
  default     = 20
}

# Pinot Variables
variable "pinot_namespace" {
  description = "Namespace de Kubernetes para Pinot"
  type        = string
  default     = "pinot"
}

variable "pinot_zookeeper_replicas" {
  description = "Número de réplicas de Zookeeper"
  type        = number
  default     = 3
}

variable "pinot_zookeeper_resources" {
  description = "Recursos para Zookeeper"
  type = object({
    requests = optional(object({
      cpu    = optional(string, "100m")
      memory = optional(string, "256Mi")
    }))
    limits = optional(object({
      cpu    = optional(string, "500m")
      memory = optional(string, "512Mi")
    }))
  })
  default = {
    requests = {
      cpu    = "100m"
      memory = "256Mi"
    }
    limits = {
      cpu    = "500m"
      memory = "512Mi"
    }
  }
}

variable "pinot_controller_replicas" {
  description = "Número de réplicas del controlador Pinot"
  type        = number
  default     = 1
}

variable "pinot_broker_replicas" {
  description = "Número de réplicas del broker Pinot"
  type        = number
  default     = 1
}

variable "pinot_server_replicas" {
  description = "Número de réplicas del servidor Pinot"
  type        = number
  default     = 2
}

variable "pinot_minion_replicas" {
  description = "Número de réplicas del minion Pinot"
  type        = number
  default     = 1
}

variable "pinot_controller_resources" {
  description = "Recursos para el controlador Pinot"
  type = object({
    requests = optional(object({
      cpu    = optional(string, "500m")
      memory = optional(string, "1Gi")
    }))
    limits = optional(object({
      cpu    = optional(string, "1000m")
      memory = optional(string, "2Gi")
    }))
  })
  default = {
    requests = {
      cpu    = "500m"
      memory = "1Gi"
    }
    limits = {
      cpu    = "1000m"
      memory = "2Gi"
    }
  }
}

variable "pinot_broker_resources" {
  description = "Recursos para el broker Pinot"
  type = object({
    requests = optional(object({
      cpu    = optional(string, "500m")
      memory = optional(string, "1Gi")
    }))
    limits = optional(object({
      cpu    = optional(string, "1000m")
      memory = optional(string, "2Gi")
    }))
  })
  default = {
    requests = {
      cpu    = "500m"
      memory = "1Gi"
    }
    limits = {
      cpu    = "1000m"
      memory = "2Gi"
    }
  }
}

variable "pinot_server_resources" {
  description = "Recursos para el servidor Pinot"
  type = object({
    requests = optional(object({
      cpu    = optional(string, "1000m")
      memory = optional(string, "2Gi")
    }))
    limits = optional(object({
      cpu    = optional(string, "2000m")
      memory = optional(string, "4Gi")
    }))
  })
  default = {
    requests = {
      cpu    = "1000m"
      memory = "2Gi"
    }
    limits = {
      cpu    = "2000m"
      memory = "4Gi"
    }
  }
}

variable "pinot_minion_resources" {
  description = "Recursos para el minion Pinot"
  type = object({
    requests = optional(object({
      cpu    = optional(string, "500m")
      memory = optional(string, "1Gi")
    }))
    limits = optional(object({
      cpu    = optional(string, "1000m")
      memory = optional(string, "2Gi")
    }))
  })
  default = {
    requests = {
      cpu    = "500m"
      memory = "1Gi"
    }
    limits = {
      cpu    = "1000m"
      memory = "2Gi"
    }
  }
}

variable "pinot_server_storage_size" {
  description = "Tamaño de almacenamiento para el servidor Pinot"
  type        = string
  default     = "20Gi"
}

variable "pinot_zookeeper_storage_size" {
  description = "Tamaño de almacenamiento para Zookeeper"
  type        = string
  default     = "10Gi"
}

variable "pinot_controller_storage_size" {
  description = "Tamaño de almacenamiento para el controlador Pinot"
  type        = string
  default     = "10Gi"
}

variable "pinot_broker_storage_size" {
  description = "Tamaño de almacenamiento para el broker Pinot"
  type        = string
  default     = "10Gi"
}

variable "pinot_minion_storage_size" {
  description = "Tamaño de almacenamiento para el minion Pinot"
  type        = string
  default     = "10Gi"
}

# Bastion Host Variables
variable "bastion_public_key" {
  description = "Public key for SSH access to bastion host"
  type        = string
}

variable "bastion_allowed_ssh_cidrs" {
  description = "CIDR blocks allowed for SSH access to bastion host"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "namespace" {
  description = "Namespace de Kubernetes para Pinot y Zookeeper"
  type        = string
  default     = "pinot"
}

variable "enable_pinot_deployment" {
  description = "Enable Pinot and Zookeeper deployment (requires EKS cluster to be ready)"
  type        = bool
  default     = false
}

# Zookeeper Helm
variable "zookeeper_release_name" {
  description = "Nombre del release de Helm para Zookeeper"
  type        = string
  default     = "zookeeper"
}
variable "zookeeper_helm_repo" {
  description = "Repo de Helm para Zookeeper"
  type        = string
  default     = "https://charts.bitnami.com/bitnami"
}
variable "zookeeper_helm_chart" {
  description = "Chart de Helm para Zookeeper"
  type        = string
  default     = "zookeeper"
}
variable "zookeeper_helm_version" {
  description = "Versión del chart de Helm de Zookeeper"
  type        = string
  default     = "13.4.0"
}
variable "zookeeper_replicas" {
  description = "Cantidad de réplicas para Zookeeper"
  type        = number
  default     = 3
}
variable "zookeeper_storage_size" {
  description = "Tamaño de almacenamiento persistente para Zookeeper"
  type        = string
  default     = "10Gi"
}
variable "zookeeper_resources" {
  description = "Recursos para Zookeeper"
  type        = map(any)
  default     = {}
}

# Pinot Helm
variable "pinot_release_name" {
  description = "Nombre del release de Helm para Pinot"
  type        = string
  default     = "pinot"
}
variable "pinot_helm_repo" {
  description = "Repo de Helm para Pinot"
  type        = string
  default     = "https://raw.githubusercontent.com/apache/pinot/master/helm"
}
variable "pinot_helm_chart" {
  description = "Chart de Helm para Pinot"
  type        = string
  default     = "pinot"
}
variable "pinot_helm_version" {
  description = "Versión del chart de Helm de Pinot"
  type        = string
  default     = "0.3.4"
}

variable "pinot_controller_replicas" {
  description = "Cantidad de réplicas para Pinot Controller"
  type        = number
  default     = 2
}
variable "pinot_controller_resources" {
  description = "Recursos para Pinot Controller"
  type        = map(any)
  default     = {}
}
variable "pinot_controller_storage_size" {
  description = "Tamaño de almacenamiento persistente para Pinot Controller"
  type        = string
  default     = "10Gi"
}

variable "pinot_broker_replicas" {
  description = "Cantidad de réplicas para Pinot Broker"
  type        = number
  default     = 2
}
variable "pinot_broker_resources" {
  description = "Recursos para Pinot Broker"
  type        = map(any)
  default     = {}
}
variable "pinot_broker_storage_size" {
  description = "Tamaño de almacenamiento persistente para Pinot Broker"
  type        = string
  default     = "10Gi"
}

variable "pinot_server_replicas" {
  description = "Cantidad de réplicas para Pinot Server"
  type        = number
  default     = 2
}
variable "pinot_server_resources" {
  description = "Recursos para Pinot Server"
  type        = map(any)
  default     = {}
}
variable "pinot_server_storage_size" {
  description = "Tamaño de almacenamiento persistente para Pinot Server"
  type        = string
  default     = "50Gi"
}

variable "pinot_minion_replicas" {
  description = "Cantidad de réplicas para Pinot Minion"
  type        = number
  default     = 1
}
variable "pinot_minion_resources" {
  description = "Recursos para Pinot Minion"
  type        = map(any)
  default     = {}
}
variable "pinot_minion_storage_size" {
  description = "Tamaño de almacenamiento persistente para Pinot Minion"
  type        = string
  default     = "10Gi"
}

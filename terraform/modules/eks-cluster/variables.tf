
variable "cluster_name" {
  description = "Nombre del cluster EKS"
  type        = string
}

variable "cluster_version" {
  description = "Versión de Kubernetes para el cluster EKS"
  type        = string
  default     = "1.27"
}

variable "vpc_id" {
  description = "ID de la VPC donde crear el cluster EKS"
  type        = string
}

variable "subnet_ids" {
  description = "Lista de subnet IDs para el cluster EKS"
  type        = list(string)
}

variable "cluster_endpoint_public_access" {
  description = "Habilitar acceso público al endpoint del cluster"
  type        = bool
  default     = true
}

variable "cluster_endpoint_private_access" {
  description = "Habilitar acceso privado al endpoint del cluster"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "Lista de CIDRs que pueden acceder al endpoint público"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# Node Group Variables
variable "node_group_name" {
  description = "Nombre del node group"
  type        = string
  default     = "main"
}

variable "node_group_instance_types" {
  description = "Tipos de instancia para el node group"
  type        = list(string)
  default     = ["m5.large"]
}

variable "node_group_capacity_type" {
  description = "Tipo de capacidad para el node group (ON_DEMAND, SPOT)"
  type        = string
  default     = "ON_DEMAND"
}

variable "node_group_min_size" {
  description = "Tamaño mínimo del node group"
  type        = number
  default     = 1
}

variable "node_group_max_size" {
  description = "Tamaño máximo del node group"
  type        = number
  default     = 10
}

variable "node_group_desired_size" {
  description = "Tamaño deseado del node group"
  type        = number
  default     = 3
}

variable "node_group_disk_size" {
  description = "Tamaño del disco en GB para los nodos"
  type        = number
  default     = 50
}

variable "node_group_ami_type" {
  description = "Tipo de AMI para los nodos (AL2_x86_64, AL2_x86_64_GPU, AL2_ARM_64)"
  type        = string
  default     = "AL2_x86_64"
}

variable "node_group_labels" {
  description = "Labels de Kubernetes para los nodos"
  type        = map(string)
  default     = {}
}

variable "node_group_taints" {
  description = "Taints de Kubernetes para los nodos"
  type        = list(object({
    key    = string
    value  = string
    effect = string
  }))
  default = []
}

variable "node_group_subnet_ids" {
  description = "Lista de subnet IDs para el node group (si es diferente del cluster)"
  type        = list(string)
  default     = null
}

variable "tags" {
  description = "Etiquetas para todos los recursos del cluster EKS"
  type        = map(string)
  default     = {}
}

variable "bastion_name" {
  description = "Name for the bastion host"
  type        = string
  default     = "msk-bastion"
}

variable "instance_type" {
  description = "EC2 instance type for bastion host"
  type        = string
  default     = "t3.micro"
}

variable "public_key" {
  description = "Public key for SSH access to bastion host"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where bastion host will be deployed"
  type        = string
}

variable "public_subnet_id" {
  description = "Public subnet ID for bastion host"
  type        = string
}

variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed for SSH access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "root_volume_size" {
  description = "Size of root volume in GB"
  type        = number
  default     = 20
}

variable "enable_elastic_ip" {
  description = "Whether to assign an Elastic IP to the bastion host"
  type        = bool
  default     = true
}

variable "git_repo_url" {
  description = "Git repository URL to clone on bastion host"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to bastion host resources"
  type        = map(string)
  default     = {}
}

# Development Environment Variables
# Override default values for dev environment

# Bastion Host Variables
variable "bastion_public_key" {
  description = "Public key for SSH access to bastion host"
  type        = string
  default     = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCtwQDlnkFo8E3iVN+i9jkvvDsL7gn/j/pvdLjmxo64YxfvWJ2CvqwEPv7GPzCH+NkaUQ+utRHkoa3kDvkJ+nZx2ib4xpFk4i6yo7RgBEj25NxFGT4xM5UcSRzAfc4HzsuprRB0SJSkrQ9NQu7nW0OaJUwVCZP+dJMmg3VPghBvSQ3SiOqmclrzCE9q/9escP+o8H65zlcQbdzD//4EnxvSks4mnZqFhpJgcGYHKs+8sKRH7qRoko+p5PNQvtrG9jg19J7N8ANAEH0RyPUuA44U4vceFtWlA5Rj4HKuHrcjG525K9QtmpWs5Pvij5K0pRM/voGDMoy8wH2gi05Xhgwx2fwwyffjIrPJH0GWAiRgA52m833ZRM+ci5IdEfZDNE+935Igh3TE/KVGp9l3Hhuq7cEDqyNdE4nHoE2x0e3DOEZ0XMpvH2cl9Hmhmpp6lqeVdDBHrdKZ11EWviyus7l1ET4fPljv3xSWcUOAACmyO4e6C0YU5KQNSFvF8lcrHFFoyeOAzVnlKAYLjUBrVVK0LcJ9d3oawKWh3XHqcFKPCxGX3MZsQ1WwS9+1YPqBPOSt/qTeS+iy0FhzOIF48GSJf2iR8cl417LQDoLJG8aV6wVBlcJBhZd2ed/EKIf90HJDjuLHKLjyNCO8RqW2eFsDNUH9E9PZ7oZu92wJDeQPiQ== daniel.melguizo@MacBook-Pro-de-Daniel.local"
}

variable "bastion_allowed_ssh_cidrs" {
  description = "CIDR blocks allowed for SSH access to bastion host"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Restrict this to your IP for security
}

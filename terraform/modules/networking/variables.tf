variable "cluster_name" {
  description = "Name used for Kubernetes discovery tags and AWS resource naming."
  type        = string
}
variable "vpc_cidr" {
  description = "IPv4 CIDR assigned to the cluster VPC."
  type        = string
}
variable "availability_zones" {
  description = "Availability zones used by the public subnets."
  type        = list(string)
  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "At least two AZs are required."
  }
}
variable "public_subnet_cidrs" {
  description = "One public subnet CIDR for each availability zone."
  type        = list(string)
  validation {
    condition     = length(var.public_subnet_cidrs) == length(var.availability_zones)
    error_message = "public_subnet_cidrs and availability_zones must contain the same number of entries."
  }
}
variable "allowed_admin_cidrs" {
  description = "CIDRs allowed to reach SSH and the Kubernetes API."
  type        = list(string)
  validation {
    condition     = length(var.allowed_admin_cidrs) > 0 && !contains(var.allowed_admin_cidrs, "0.0.0.0/0")
    error_message = "Supply restricted admin CIDRs; 0.0.0.0/0 is rejected."
  }
}
variable "api_port" {
  description = "Kubernetes API TCP port allowed from administrative networks."
  type        = number
  default     = 6443
  validation {
    condition     = var.api_port >= 1 && var.api_port <= 65535 && floor(var.api_port) == var.api_port
    error_message = "api_port must be an integer between 1 and 65535."
  }
}

variable "tags" {
  description = "Additional tags applied to all supported AWS resources."
  type        = map(string)
  default     = {}
}

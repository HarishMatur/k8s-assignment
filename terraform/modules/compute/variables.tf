variable "cluster_name" {
  description = "Name used for Kubernetes discovery tags and AWS resource naming."
  type        = string
}
variable "ssh_key_name" {
  description = "EC2 key pair name. Terraform creates it when create_ssh_key is true."
  type        = string
}
variable "create_ssh_key" {
  description = "Create the EC2 key pair from ssh_public_key."
  type        = bool
  default     = true
}
variable "ssh_public_key" {
  description = "OpenSSH-format public key used when create_ssh_key is true."
  type        = string
  default     = null

  validation {
    condition = (
      !var.create_ssh_key ||
      (var.ssh_public_key != null && can(regex("^ssh-(rsa|ed25519)\\s+", trimspace(var.ssh_public_key))))
    )
    error_message = "ssh_public_key must be a valid ssh-rsa or ssh-ed25519 public key when create_ssh_key is true."
  }
}
variable "ami_id" {
  description = "Ubuntu AMI used by all cluster nodes."
  type        = string
}
variable "control_plane_instance_type" {
  description = "EC2 instance type for the control-plane node."
  type        = string
  default     = "t3.medium"
}
variable "worker_instance_type" {
  description = "EC2 instance type for worker nodes."
  type        = string
  default     = "t3.medium"
}
variable "worker_count" {
  description = "Number of worker nodes."
  type        = number
  default     = 2
  validation {
    condition     = var.worker_count >= 2
    error_message = "This assignment requires at least two worker nodes."
  }
}
variable "root_volume_size" {
  description = "Root volume size in GiB for every node."
  type        = number
  default     = 30
}
variable "node_storage" {
  description = "Encrypted node root disk type, performance, and optional KMS key."
  type = object({
    volume_type = optional(string, "gp3")
    iops        = optional(number, 3000)
    throughput  = optional(number, 125)
    kms_key_id  = optional(string)
  })
  default = {}
  validation {
    condition     = contains(["gp3", "gp2", "io1", "io2"], var.node_storage.volume_type)
    error_message = "Use a supported SSD root volume type: gp3, gp2, io1, or io2."
  }
}
variable "control_plane_private_ip" {
  description = "Stable private address used by the Kubernetes API endpoint."
  type        = string
}
variable "control_plane_user_data" {
  description = "Rendered bootstrap script for the control-plane node."
  type        = string
  sensitive   = true
}
variable "worker_user_data" {
  description = "Rendered bootstrap script shared by worker nodes."
  type        = string
  sensitive   = true
}
variable "tags" {
  description = "Additional tags applied to all supported AWS resources."
  type        = map(string)
  default     = {}
}

variable "subnet_ids" {
  description = "Public subnets for the control plane and workers, in AZ order."
  type        = list(string)
}
variable "security_group_id" {
  description = "Shared node security group."
  type        = string
}

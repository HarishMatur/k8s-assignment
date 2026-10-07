variable "aws_region" {
  description = "AWS region where the cluster is provisioned."
  type        = string
  default     = "ap-south-1"
}
variable "cluster_name" {
  description = "Name used for resources, discovery tags, and SSM parameters."
  type        = string
  default     = "k8s-assignment"
}
variable "vpc_cidr" {
  description = "IPv4 CIDR for the cluster VPC."
  type        = string
  default     = "10.50.0.0/16"
}
variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs, in the same order as availability_zones."
  type        = list(string)
}

variable "availability_zones" {
  description = "Availability zones for the public subnets."
  type        = list(string)
}

variable "allowed_admin_cidrs" {
  description = "Restricted IPv4 CIDRs allowed to access SSH and the Kubernetes API."
  type        = list(string)
}

variable "ssh_key_name" {
  description = "EC2 key pair to create or reuse."
  type        = string
}

variable "create_ssh_key" {
  description = "Create an AWS EC2 key pair from the local public key."
  type        = bool
  default     = true
}
variable "ssh_public_key_path" {
  description = "Path to an OpenSSH public key. Used only when create_ssh_key is true."
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}
variable "ami_id" {
  description = "AMI override; null selects the latest Canonical Ubuntu 24.04 amd64 image."
  type        = string
  default     = null
}
variable "control_plane_instance_type" {
  description = "EC2 instance type for the control-plane node."
  type        = string
  default     = "t3.medium"
}
variable "worker_instance_type" {
  description = "EC2 instance type for each worker node."
  type        = string
  default     = "t3.medium"
}
variable "worker_count" {
  description = "Number of worker nodes; the cluster module requires at least two."
  type        = number
  default     = 2
}
variable "root_volume_size" {
  description = "Root disk capacity in GiB for each node."
  type        = number
  default     = 30
}
variable "kubernetes_version" {
  description = "Kubernetes minor version used for the package repository, such as 1.31."
  type        = string
  default     = "1.31"
  validation {
    condition     = can(regex("^1\\.[0-9]+$", var.kubernetes_version))
    error_message = "Use a minor version such as 1.31; pin packages separately."
  }
}
variable "kubernetes_package_version" {
  description = "Exact Debian version for kubelet, kubeadm, and kubectl, or null for latest in the selected minor repository."
  type        = string
  default     = "1.31.14-1.1"
  validation {
    condition     = var.kubernetes_package_version == null ? true : startswith(var.kubernetes_package_version, "${var.kubernetes_version}.")
    error_message = "The package version must belong to kubernetes_version."
  }
}

variable "ami_lookup" {
  description = "AMI lookup settings used when selecting the Ubuntu image. Bootstrap currently supports Ubuntu amd64."
  type = object({
    owners       = list(string)
    name_pattern = string
    most_recent  = bool
  })
  default = {
    owners       = ["099720109477"]
    name_pattern = "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"
    most_recent  = true
  }
}

variable "bootstrap" {
  description = "API, kubeadm, package installer, and worker retry settings."
  type = object({
    control_plane_host_number = optional(number, 10)
    api_port                  = optional(number, 6443)
    kubeadm_api_version       = optional(string, "kubeadm.k8s.io/v1beta4")
    join_token_ttl            = optional(string, "2h")
    join_attempts             = optional(number, 120)
    join_retry_seconds        = optional(number, 15)
    aws_cli_url               = optional(string, "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip")
    containerd_package        = optional(string, "containerd")
  })
  default = {}
  validation {
    condition = (
      var.bootstrap.api_port >= 1 && var.bootstrap.api_port <= 65535 && floor(var.bootstrap.api_port) == var.bootstrap.api_port &&
      var.bootstrap.join_attempts > 0 && floor(var.bootstrap.join_attempts) == var.bootstrap.join_attempts &&
      var.bootstrap.join_retry_seconds > 0 && floor(var.bootstrap.join_retry_seconds) == var.bootstrap.join_retry_seconds &&
      var.bootstrap.control_plane_host_number >= 4 && floor(var.bootstrap.control_plane_host_number) == var.bootstrap.control_plane_host_number
    )
    error_message = "Use a valid TCP port, positive integer retry settings, and an unreserved subnet host number."
  }
}

variable "addon_versions" {
  description = "Tested add-on chart versions and AWS CCM image tag; select versions compatible with the Kubernetes minor version."
  type = object({
    calico    = optional(string, "v3.29.3")
    ccm_chart = optional(string, "0.0.11")
    ccm_image = optional(string, "v1.31.6")
    ebs_csi   = optional(string, "2.66.0")
  })
  default = {}
  validation {
    condition     = startswith(var.addon_versions.ccm_image, "v${var.kubernetes_version}.")
    error_message = "The AWS CCM image minor version must match kubernetes_version."
  }
}

variable "node_storage" {
  description = "Root disk performance and optional customer-managed KMS key; encryption remains enabled."
  type = object({
    volume_type = optional(string, "gp3")
    iops        = optional(number, 3000)
    throughput  = optional(number, 125)
    kms_key_id  = optional(string)
  })
  default = {}
}
variable "pod_cidr" {
  description = "IPv4 CIDR allocated to pods; must match the CNI configuration."
  type        = string
  default     = "192.168.0.0/16"
}
variable "service_cidr" {
  description = "IPv4 CIDR allocated to Kubernetes Services."
  type        = string
  default     = "10.96.0.0/12"
}
variable "bootstrap_method" {
  description = "remote-exec for fresh assignment deployments; cloud-init preserves existing nodes. Switching replaces nodes."
  type        = string
  default     = "cloud-init"
  validation {
    condition     = contains(["cloud-init", "remote-exec"], var.bootstrap_method)
    error_message = "Use cloud-init or remote-exec."
  }
}

variable "provisioner_private_key_path" {
  description = "Local SSH private key path for Terraform provisioners."
  type        = string
  default     = "~/.ssh/id_ed25519"
}

variable "tags" {
  description = "Additional AWS resource tags."
  type        = map(string)
  default = {
    Environment = "assignment"
    Owner       = "Harish-Matur"
  }
}

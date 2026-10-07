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


variable "worker_count" {
  description = "Number of worker nodes to bootstrap."
  type        = number
}
variable "control_plane_instance_id" {
  description = "Control-plane ID used to track bootstrap replacement."
  type        = string
}
variable "control_plane_public_ip" {
  description = "Control-plane SSH address."
  type        = string
}
variable "worker_instance_ids" {
  description = "Worker IDs in the same order as worker_public_ips."
  type        = list(string)
}
variable "worker_public_ips" {
  description = "Worker SSH addresses."
  type        = list(string)
}
variable "control_plane_user_data" {
  description = "Rendered control-plane bootstrap script."
  type        = string
  sensitive   = true
}
variable "worker_user_data" {
  description = "Rendered worker bootstrap script."
  type        = string
  sensitive   = true
}

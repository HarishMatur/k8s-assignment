locals {
  control_plane_private_ip = cidrhost(var.public_subnet_cidrs[0], var.bootstrap.control_plane_host_number)
  ssh_public_key           = var.create_ssh_key ? file(pathexpand(var.ssh_public_key_path)) : null

  common = templatefile("${path.module}/modules/kubernetes/templates/common.sh.tftpl", {
    kubernetes_version         = var.kubernetes_version
    kubernetes_package_version = var.kubernetes_package_version
    aws_cli_url                = var.bootstrap.aws_cli_url
    containerd_package         = var.bootstrap.containerd_package
  })

  control_plane_user_data = templatefile("${path.module}/modules/kubernetes/templates/control-plane.sh.tftpl", {
    common              = local.common
    cluster_name        = var.cluster_name
    api_private_ip      = local.control_plane_private_ip
    pod_cidr            = var.pod_cidr
    service_cidr        = var.service_cidr
    api_port            = var.bootstrap.api_port
    kubeadm_api_version = var.bootstrap.kubeadm_api_version
    join_token_ttl      = var.bootstrap.join_token_ttl
  })

  worker_user_data = templatefile("${path.module}/modules/kubernetes/templates/worker.sh.tftpl", {
    common             = local.common
    cluster_name       = var.cluster_name
    aws_region         = var.aws_region
    join_attempts      = var.bootstrap.join_attempts
    join_retry_seconds = var.bootstrap.join_retry_seconds
  })
}

module "networking" {
  source = "./modules/networking"

  cluster_name        = var.cluster_name
  vpc_cidr            = var.vpc_cidr
  availability_zones  = var.availability_zones
  public_subnet_cidrs = var.public_subnet_cidrs
  allowed_admin_cidrs = var.allowed_admin_cidrs
  api_port            = var.bootstrap.api_port
  tags                = var.tags
}

module "compute" {
  source = "./modules/compute"

  cluster_name      = var.cluster_name
  subnet_ids        = module.networking.subnet_ids
  security_group_id = module.networking.security_group_id
  tags              = var.tags

  ssh_key_name   = var.ssh_key_name
  create_ssh_key = var.create_ssh_key
  ssh_public_key = local.ssh_public_key

  ami_id                      = coalesce(var.ami_id, data.aws_ami.ubuntu.id)
  control_plane_instance_type = var.control_plane_instance_type
  worker_instance_type        = var.worker_instance_type
  worker_count                = var.worker_count
  root_volume_size            = var.root_volume_size
  node_storage                = var.node_storage

  control_plane_private_ip = local.control_plane_private_ip
  control_plane_user_data  = var.bootstrap_method == "cloud-init" ? local.control_plane_user_data : "#!/bin/bash\n# Terraform remote-exec manages bootstrap.\n"
  worker_user_data         = var.bootstrap_method == "cloud-init" ? local.worker_user_data : "#!/bin/bash\n# Terraform remote-exec manages bootstrap.\n"

  depends_on = [module.networking]
}

module "kubernetes" {
  source = "./modules/kubernetes"

  bootstrap_method             = var.bootstrap_method
  provisioner_private_key_path = var.provisioner_private_key_path
  worker_count                 = var.worker_count
  control_plane_instance_id    = module.compute.control_plane_instance_id
  control_plane_public_ip      = module.compute.control_plane_public_ip
  worker_instance_ids          = module.compute.worker_instance_ids
  worker_public_ips            = module.compute.worker_public_ips
  control_plane_user_data      = local.control_plane_user_data
  worker_user_data             = local.worker_user_data
}

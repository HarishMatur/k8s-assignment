resource "aws_key_pair" "cluster" {
  count = var.create_ssh_key ? 1 : 0

  key_name   = var.ssh_key_name
  public_key = var.ssh_public_key != null ? trimspace(var.ssh_public_key) : null

  tags = merge(local.common_tags, {
    Name = var.ssh_key_name
  })
}

resource "aws_instance" "control_plane" {
  ami           = var.ami_id
  instance_type = var.control_plane_instance_type
  subnet_id     = var.subnet_ids[0]
  private_ip    = var.control_plane_private_ip

  vpc_security_group_ids      = [var.security_group_id]
  key_name                    = local.key_name
  iam_instance_profile        = aws_iam_instance_profile.nodes.name
  associate_public_ip_address = true

  user_data                   = var.control_plane_user_data
  user_data_replace_on_change = true

  root_block_device {
    encrypted             = true
    volume_type           = var.node_storage.volume_type
    iops                  = var.node_storage.volume_type == "gp2" ? null : var.node_storage.iops
    throughput            = var.node_storage.volume_type == "gp3" ? var.node_storage.throughput : null
    kms_key_id            = var.node_storage.kms_key_id
    volume_size           = var.root_volume_size
    delete_on_termination = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  tags = merge(local.common_tags, {
    Name                = "${var.cluster_name}-control-plane"
    (local.cluster_tag) = "owned"
    NodeRole            = "control-plane"
  })

  depends_on = [aws_iam_role_policy.cluster_operations]
}

resource "aws_instance" "worker" {
  count = var.worker_count

  ami           = var.ami_id
  instance_type = var.worker_instance_type
  subnet_id     = var.subnet_ids[(count.index + 1) % length(var.subnet_ids)]

  vpc_security_group_ids      = [var.security_group_id]
  key_name                    = local.key_name
  iam_instance_profile        = aws_iam_instance_profile.nodes.name
  associate_public_ip_address = true

  user_data                   = var.worker_user_data
  user_data_replace_on_change = true

  root_block_device {
    encrypted             = true
    volume_type           = var.node_storage.volume_type
    iops                  = var.node_storage.volume_type == "gp2" ? null : var.node_storage.iops
    throughput            = var.node_storage.volume_type == "gp3" ? var.node_storage.throughput : null
    kms_key_id            = var.node_storage.kms_key_id
    volume_size           = var.root_volume_size
    delete_on_termination = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  tags = merge(local.common_tags, {
    Name                = format("%s-worker-%02d", var.cluster_name, count.index + 1)
    (local.cluster_tag) = "owned"
    NodeRole            = "worker"
  })

  depends_on = [aws_instance.control_plane]
}

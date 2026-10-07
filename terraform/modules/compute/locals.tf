locals {
  common_tags = merge(var.tags, {
    ManagedBy = "terraform"
    Cluster   = var.cluster_name
  })

  cluster_tag = "kubernetes.io/cluster/${var.cluster_name}"
  key_name    = var.create_ssh_key ? aws_key_pair.cluster[0].key_name : var.ssh_key_name
}

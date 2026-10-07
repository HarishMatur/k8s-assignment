locals {
  common_tags = merge(var.tags, {
    ManagedBy = "terraform"
    Cluster   = var.cluster_name
  })

  cluster_tag = "kubernetes.io/cluster/${var.cluster_name}"
}

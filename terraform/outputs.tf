output "control_plane_public_ip" {
  description = "Public IPv4 address used for SSH and direct API access."
  value       = module.compute.control_plane_public_ip
}

output "cluster_name" {
  description = "Cluster name used in AWS tags and SSM parameter paths."
  value       = var.cluster_name
}

output "aws_region" {
  description = "AWS region containing the cluster."
  value       = var.aws_region
}

output "worker_public_ips" {
  description = "Public IPv4 addresses used to access worker nodes."
  value       = module.compute.worker_public_ips
}

output "get_kubeconfig_command" {
  description = "Download the admin kubeconfig and select the public API endpoint."
  value       = "aws ssm get-parameter --region ${var.aws_region} --name /${var.cluster_name}/kubeconfig --with-decryption --query Parameter.Value --output text > kubeconfig && sed -i.bak 's/${local.control_plane_private_ip}/${module.compute.control_plane_public_ip}/g' kubeconfig && chmod 600 kubeconfig"
}
output "deployment_settings" {
  description = "Non-secret settings shared by access, recovery, and add-on scripts."
  value = {
    addon_versions = var.addon_versions
    pod_cidr       = var.pod_cidr
    api_port       = var.bootstrap.api_port
    join_token_ttl = var.bootstrap.join_token_ttl
  }
}

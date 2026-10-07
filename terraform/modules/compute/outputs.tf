output "control_plane_public_ip" {
  description = "Public address of the control-plane node."
  value       = aws_instance.control_plane.public_ip
}
output "control_plane_private_ip" {
  description = "Private Kubernetes API endpoint address."
  value       = aws_instance.control_plane.private_ip
}
output "worker_public_ips" {
  description = "Public addresses of worker nodes."
  value       = aws_instance.worker[*].public_ip
}
output "node_role_arn" {
  description = "IAM role assumed by the cluster nodes."
  value       = aws_iam_role.nodes.arn
}
output "control_plane_instance_id" {
  description = "Control-plane instance ID for bootstrap lifecycle tracking."
  value       = aws_instance.control_plane.id
}

output "worker_instance_ids" {
  description = "Worker instance IDs in public-IP output order."
  value       = aws_instance.worker[*].id
}

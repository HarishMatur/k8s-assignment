output "vpc_id" {
  description = "ID of the cluster VPC."
  value       = aws_vpc.cluster.id
}
output "subnet_ids" {
  description = "Public subnet IDs used by the cluster nodes and load balancers."
  value       = aws_subnet.public[*].id
}
output "security_group_id" {
  description = "Security group shared by the Kubernetes nodes."
  value       = aws_security_group.nodes.id
}

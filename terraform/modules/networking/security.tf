resource "aws_security_group" "nodes" {
  name_prefix = "${var.cluster_name}-nodes-"
  description = "Traffic permitted to and between Kubernetes nodes"
  vpc_id      = aws_vpc.cluster.id

  ingress {
    description = "SSH from approved administration networks"
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = var.allowed_admin_cidrs
  }

  ingress {
    description = "Kubernetes API from approved administration networks"
    protocol    = "tcp"
    from_port   = var.api_port
    to_port     = var.api_port
    cidr_blocks = var.allowed_admin_cidrs
  }

  ingress {
    description = "Kubernetes node-to-node traffic"
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    self        = true
  }

  ingress {
    description = "NodePort health checks and data traffic"
    protocol    = "tcp"
    from_port   = 30000
    to_port     = 32767
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-nodes"
  })

  lifecycle {
    create_before_destroy = true
  }
}

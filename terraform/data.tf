data "aws_ami" "ubuntu" {
  most_recent = var.ami_lookup.most_recent
  owners      = var.ami_lookup.owners

  filter {
    name   = "name"
    values = [var.ami_lookup.name_pattern]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

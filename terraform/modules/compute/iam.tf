data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "nodes" {
  name_prefix        = "${var.cluster_name}-nodes-"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
  tags               = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloud_controller" {
  role       = aws_iam_role.nodes.name
  policy_arn = "arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess"
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.nodes.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

data "aws_iam_policy_document" "cluster_operations" {
  statement {
    sid = "BootstrapParameters"
    actions = [
      "ssm:DeleteParameter",
      "ssm:GetParameter",
      "ssm:PutParameter"
    ]
    resources = ["arn:aws:ssm:*:*:parameter/${var.cluster_name}/*"]
  }

  statement {
    sid = "NodeAndVolumeDiscovery"
    actions = [
      "ec2:AttachVolume",
      "ec2:CreateTags",
      "ec2:CreateVolume",
      "ec2:DeleteVolume",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeInstances",
      "ec2:DescribeRegions",
      "ec2:DescribeRouteTables",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSubnets",
      "ec2:DescribeVolumes",
      "ec2:DescribeVolumesModifications",
      "ec2:DetachVolume",
      "ec2:ModifyVolume"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "cluster_operations" {
  name   = "cluster-operations"
  role   = aws_iam_role.nodes.id
  policy = data.aws_iam_policy_document.cluster_operations.json
}

resource "aws_iam_instance_profile" "nodes" {
  name_prefix = "${var.cluster_name}-"
  role        = aws_iam_role.nodes.name
}

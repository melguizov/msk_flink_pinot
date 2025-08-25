# IAM role for bastion host with MSK permissions
resource "aws_iam_role" "bastion_role" {
  name = "${var.bastion_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# IAM policy for MSK and Glue permissions
resource "aws_iam_policy" "bastion_msk_policy" {
  name        = "${var.bastion_name}-msk-policy"
  description = "Policy for bastion host to access MSK cluster and Glue schema registry"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
            "kafka-cluster:Connect",
            "kafka-cluster:AlterCluster",
            "kafka-cluster:DescribeCluster",
            "kafka-cluster:*Topic*",
            "kafka-cluster:WriteData",
            "kafka-cluster:ReadData",
            "kafka:GetBootstrapBrokers",
            "kafka:ListClusters"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "glue:RegisterSchemaVersion",
          "glue:GetSchema*",
          "glue:ListSchemas"
        ]
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}

# IAM policy for EC2 networking permissions
resource "aws_iam_policy" "bastion_ec2_policy" {
  name        = "${var.bastion_name}-ec2-policy"
  description = "Policy for bastion host to describe EC2 networking resources"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EC2ReadForNetworkingLookups"
        Effect = "Allow"
        Action = [
          "ec2:DescribeSubnets",
          "ec2:DescribeVpcs",
          "ec2:DescribeRouteTables",
          "ec2:DescribeSecurityGroups"
        ]
        Resource = "*"
        Condition = {
          StringEquals = { "aws:RequestedRegion" = "us-east-1" }
        }
      }
    ]
  })

  tags = var.tags
}

# Attach MSK policy to role
resource "aws_iam_role_policy_attachment" "bastion_msk_policy_attachment" {
  role       = aws_iam_role.bastion_role.name
  policy_arn = aws_iam_policy.bastion_msk_policy.arn
}

# Attach EC2 policy to role
resource "aws_iam_role_policy_attachment" "bastion_ec2_policy_attachment" {
  role       = aws_iam_role.bastion_role.name
  policy_arn = aws_iam_policy.bastion_ec2_policy.arn
}

# Instance profile for the bastion host
resource "aws_iam_instance_profile" "bastion_profile" {
  name = "${var.bastion_name}-profile"
  role = aws_iam_role.bastion_role.name

  tags = var.tags
}

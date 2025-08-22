# Kinesis Analytics service execution role trust policy
data "aws_iam_policy_document" "flink_service_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["kinesisanalytics.amazonaws.com"]
    }
  }
}

# Kinesis Analytics service execution role
resource "aws_iam_role" "flink_service_execution_role" {
  name               = "${var.flink_app_name}-service-execution-role"
  assume_role_policy = data.aws_iam_policy_document.flink_service_assume_role.json
}

# CloudWatch logs policy for Kinesis Analytics
resource "aws_iam_role_policy_attachment" "flink_service_logs" {
  role       = aws_iam_role.flink_service_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

# Custom VPC access policy for Kinesis Analytics
data "aws_iam_policy_document" "flink_vpc_access" {
  statement {
    sid    = "VPCReadOnlyPermissions"
    effect = "Allow"
    actions = [
      "ec2:DescribeVpcs",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeDhcpOptions"
    ]
    resources = ["*"]
  }
  
  statement {
    sid    = "ENIReadWritePermissions"
    effect = "Allow"
    actions = [
      "ec2:CreateNetworkInterface",
      "ec2:CreateNetworkInterfacePermission",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DeleteNetworkInterface"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "flink_vpc_access" {
  name   = "FlinkVPCAccess"
  policy = data.aws_iam_policy_document.flink_vpc_access.json
}

resource "aws_iam_role_policy_attachment" "flink_service_vpc" {
  role       = aws_iam_role.flink_service_execution_role.name
  policy_arn = aws_iam_policy.flink_vpc_access.arn
}

data "aws_iam_policy_document" "flink_msk_access" {
  count = var.msk_arn != "" ? 1 : 0
  
  statement {
    actions = [
      "kafka:DescribeCluster",
      "kafka:GetBootstrapBrokers",
      "kafka:ListClusters",
      "kafka:DescribeClusterOperation",
      "kafka:DescribeConfigurationRevision",
      "kafka:ListNodes",
      "kafka:ReadData",
      "kafka:WriteData"
    ]
    resources = [var.msk_arn]
  }
}

resource "aws_iam_policy" "flink_msk_access" {
  count  = var.msk_arn != "" ? 1 : 0
  name   = var.iam_policy_name
  policy = data.aws_iam_policy_document.flink_msk_access[0].json
}

resource "aws_iam_role_policy_attachment" "flink_attach_msk" {
  count      = var.msk_arn != "" && var.emr_instance_profile_role_name != "" ? 1 : 0
  role       = var.emr_instance_profile_role_name
  policy_arn = aws_iam_policy.flink_msk_access[0].arn
}

# Attach MSK access policy to Flink service execution role
resource "aws_iam_role_policy_attachment" "flink_service_msk_access" {
  count      = var.msk_arn != "" ? 1 : 0
  role       = aws_iam_role.flink_service_execution_role.name
  policy_arn = aws_iam_policy.flink_msk_access[0].arn
}

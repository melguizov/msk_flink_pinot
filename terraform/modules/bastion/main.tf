# Data source for latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Key pair for bastion host
resource "aws_key_pair" "bastion" {
  key_name   = "${var.bastion_name}-key"
  public_key = var.public_key
  tags       = var.tags
}

# Bastion host EC2 instance
resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.bastion.key_name
  subnet_id              = var.public_subnet_id
  vpc_security_group_ids = [aws_security_group.bastion.id]

  associate_public_ip_address = true

  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    git_repo_url = var.git_repo_url
  }))

  root_block_device {
    volume_type = "gp3"
    volume_size = var.root_volume_size
    encrypted   = true
  }

  tags = merge(var.tags, {
    Name = var.bastion_name
    Type = "Bastion Host"
  })
}

# Security group for bastion host
resource "aws_security_group" "bastion" {
  name        = "${var.bastion_name}-sg"
  description = "Security group for bastion host"
  vpc_id      = var.vpc_id

  # SSH access from allowed IPs
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
    description = "SSH access to bastion host"
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(var.tags, {
    Name = "${var.bastion_name}-sg"
  })
}

# Elastic IP for bastion host
resource "aws_eip" "bastion" {
  count    = var.enable_elastic_ip ? 1 : 0
  instance = aws_instance.bastion.id
  domain   = "vpc"

  tags = merge(var.tags, {
    Name = "${var.bastion_name}-eip"
  })

  depends_on = [aws_instance.bastion]
}

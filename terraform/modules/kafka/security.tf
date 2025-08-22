resource "aws_security_group" "msk" {
  name        = var.sg_msk_name
  description = "Security group for MSK cluster"
  vpc_id      = var.vpc_id

  # Allow access from EMR/Flink
  ingress {
    from_port       = 9092
    to_port         = 9094
    protocol        = "tcp"
    security_groups = [var.sg_emr_id]
    description     = "Permitir acceso desde EMR a brokers MSK (PLAINTEXT, TLS, SASL)"
  }

  # Allow access from bastion host
  ingress {
    from_port       = 9092
    to_port         = 9098
    protocol        = "tcp"
    security_groups = [var.bastion_security_group_id]
    description     = "Allow access from bastion host to MSK cluster"
  }

  # Allow Zookeeper access from bastion
  ingress {
    from_port       = 2181
    to_port         = 2181
    protocol        = "tcp"
    security_groups = [var.bastion_security_group_id]
    description     = "Allow Zookeeper access from bastion host"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.sg_msk_tags
}

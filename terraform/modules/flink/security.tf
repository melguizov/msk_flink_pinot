resource "aws_security_group" "flink" {
  name        = var.flink_sg_name
  description = "Security group para Managed Flink"
  vpc_id      = var.flink_vpc_id

  dynamic "egress" {
    for_each = var.msk_sg_id != "" ? [1] : []
    content {
      from_port       = 9092
      to_port         = 9094
      protocol        = "tcp"
      security_groups = [var.msk_sg_id]
      description     = "Permitir salida hacia brokers MSK (PLAINTEXT, TLS, SASL)"
    }
  }

  tags = var.flink_sg_tags
}

resource "aws_security_group" "emr" {
  name        = var.sg_emr_name
  description = "Security group for EMR cluster (Flink)"
  vpc_id      = var.vpc_id

  dynamic "egress" {
    for_each = var.sg_msk_id != "" ? [1] : []
    content {
      from_port       = 9092
      to_port         = 9094
      protocol        = "tcp"
      security_groups = [var.sg_msk_id]
      description     = "Permitir salida hacia brokers MSK (PLAINTEXT, TLS, SASL)"
    }
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.sg_emr_tags
}

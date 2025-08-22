resource "aws_msk_cluster" "this" {
  cluster_name           = var.cluster_name
  kafka_version          = var.kafka_version
  number_of_broker_nodes = var.number_of_broker_nodes

  broker_node_group_info {
    instance_type   = var.broker_instance_type
    client_subnets  = var.subnet_ids
    security_groups = var.security_group_ids
    storage_info {
      ebs_storage_info {
        volume_size = var.broker_ebs_volume_size
      }
    }
  }

  encryption_info {
    encryption_in_transit {
      client_broker = var.encryption_in_transit_client_broker
      in_cluster    = var.encryption_in_transit_in_cluster
    }
    encryption_at_rest_kms_key_arn = var.encryption_at_rest_kms_key_arn
  }

  enhanced_monitoring = var.enhanced_monitoring

  logging_info {
    broker_logs {
      cloudwatch_logs {
        enabled   = var.log_cloudwatch_enabled
        log_group = var.log_cloudwatch_log_group
      }
      firehose {
        enabled         = var.log_firehose_enabled
        delivery_stream = var.log_firehose_delivery_stream
      }
      s3 {
        enabled = var.log_s3_enabled
        bucket  = var.log_s3_bucket
        prefix  = var.log_s3_prefix
      }
    }
  }

  client_authentication {
    sasl {
      iam   = var.client_auth_sasl_iam
      scram = var.client_auth_sasl_scram
    }
    tls {
      certificate_authority_arns = []
    }
    unauthenticated = var.client_auth_unauthenticated
  }

  dynamic "configuration_info" {
    for_each = var.configuration_arn != null ? [1] : []
    content {
      arn      = var.configuration_arn
      revision = var.configuration_revision
    }
  }

  tags = var.tags
}

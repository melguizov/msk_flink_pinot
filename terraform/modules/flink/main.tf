resource "aws_kinesisanalyticsv2_application" "flink" {
  name                   = var.flink_app_name
  runtime_environment    = var.flink_runtime_environment
  service_execution_role = aws_iam_role.flink_service_execution_role.arn

  application_configuration {
    application_code_configuration {
      dynamic "code_content" {
        for_each = var.flink_code_file_key != "" ? [1] : []
        content {
          s3_content_location {
            bucket_arn = var.flink_code_bucket_arn
            file_key   = var.flink_code_file_key
          }
        }
      }
      code_content_type = var.flink_code_content_type
    }

    flink_application_configuration {
      checkpoint_configuration {
        configuration_type = var.flink_checkpoint_configuration_type
      }
      monitoring_configuration {
        configuration_type = var.flink_monitoring_configuration_type
      }
    }

    vpc_configuration {
      subnet_ids         = var.flink_subnet_ids
      security_group_ids = [aws_security_group.flink.id]
    }
  }
}

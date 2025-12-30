data "aws_caller_identity" "paymentology" {}
## VPC for Paymentology Application
resource "aws_vpc" "pay-demo-vpc" {
  cidr_block = var.vpc_cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true   

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-vpc"
    }
  )
                                                                             
}

# VPC Flow Logs
resource "aws_flow_log" "vpc_flow_logs_pay_app" {
  log_destination      = aws_s3_bucket.s3_logs_pay_app.arn
  log_destination_type = "s3"
  traffic_type         = "ALL"
  vpc_id               = aws_vpc.pay-demo-vpc.id

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-vpc-flow-logs"
    }
  )
}

# S3 Bucket for Logging

resource "aws_s3_bucket" "s3_logs_pay_app" {
  bucket = "${var.app_name}-logs-${data.aws_caller_identity.paymentology.account_id}"

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-log-bucket"
    }
  )
}

resource "aws_s3_bucket_ownership_controls" "s3_logs_ownership" {
  bucket = aws_s3_bucket.s3_logs_pay_app.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# Enforce private access to the logging bucket.
resource "aws_s3_bucket_public_access_block" "s3_logs_pay_app" {
  bucket = aws_s3_bucket.s3_logs_pay_app.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Add a policy to allow logging services to write to the bucket.
resource "aws_s3_bucket_policy" "s3_logs_pay_app" {
  bucket = aws_s3_bucket.s3_logs_pay_app.id
  policy = data.aws_iam_policy_document.s3_logs_pay_app.json
}

# Enable lifecycle rule to manage log file retention.
resource "aws_s3_bucket_lifecycle_configuration" "s3_logs_pay_app" {
  bucket = aws_s3_bucket.s3_logs_pay_app.id

  rule {
    id     = "log-retention"
    status = "Enabled"
    filter {}

# Transition non-current versions to a cheaper storage class after 30 days.
    noncurrent_version_transition {
      noncurrent_days          = 30
      storage_class = "STANDARD_IA"
    }

# Expire non-current versions after 365 days.
    noncurrent_version_expiration {
      noncurrent_days = 365
    }

# Expire incomplete multipart uploads after 7 days.
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

#SSM Parameter for CloudWatch Agent Configuration
resource "aws_ssm_parameter" "cw_agent_config_pay_app" {
  name  = "/${var.app_name}/cw-agent-config"
  type  = "String"
# Read the configuration from the external JSON file.
  value = file("${path.module}/pay_json/cw_agent_config.json")

    tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-ssm-param-cw-agent-config"
    }
  )
}

# --- Patch Management ---
# Defines the rules for which patches to approve and install.

resource "aws_ssm_patch_baseline" "baseline_pay_app" {
  name             = "${var.app_name}-amazon-linux-2-baseline"
  operating_system = "AMAZON_LINUX_2"
  description      = "Baseline for Amazon Linux 2 with a 7-day auto-approval delay for critical patches."

# Rule to auto-approve critical security updates after 7 days.
  approval_rule {
    approve_after_days = 7
    compliance_level   = "CRITICAL"
    patch_filter {
      key    = "CLASSIFICATION"
      values = ["Security"]
    }
    patch_filter {
      key    = "SEVERITY"
      values = ["Critical", "Important"]
    }
  }

# Rule to auto-approve non-security bug fixes after 7 days.
  approval_rule {
    approve_after_days = 7
    compliance_level   = "MEDIUM"
    patch_filter {
      key    = "PRODUCT"
      values = ["AmazonLinux2"]
    }
    patch_filter {
      key    = "CLASSIFICATION"
      values = ["Bugfix"]
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-patch-baseline"
    }
  )
}

# Patch Group-Associates the patch baseline with a group of instances identified by the "PatchGroup" tag.
resource "aws_ssm_patch_group" "patch_group_pay_app" {
  baseline_id = aws_ssm_patch_baseline.baseline_pay_app.id
  patch_group = "${var.app_name}-ec2-prod"
}

# Maintenance Window 
# Defines the schedule for patching operations.

resource "aws_ssm_maintenance_window" "mw_pay_app" {
  name     = "${var.app_name}-weekly-patching"
# Runs every Sunday at 03:00 AM UTC.
  schedule = "cron(0 3 ? * SUN *)"
  duration = 3  
  cutoff   = 1  

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-maintenance-window"
    }
  )
}

# Maintenance Window Target
# Registers our EC2 instances as a target for the maintenance window.

resource "aws_ssm_maintenance_window_target" "mwt_pay_app" {
  window_id     = aws_ssm_maintenance_window.mw_pay_app.id
  name          = "${var.app_name}-ec2-targets"
  resource_type = "INSTANCE"

  targets {
    key    = "tag:PatchGroup"
    values = [aws_ssm_patch_group.patch_group_pay_app.patch_group]
  }
}

# Maintenance Window Task
# Defines the patching task to be run during the window.
resource "aws_ssm_maintenance_window_task" "mwt_run_patch_baseline" {
  window_id        = aws_ssm_maintenance_window.mw_pay_app.id
  task_arn         = "AWS-RunPatchBaseline"
  task_type        = "RUN_COMMAND"
  priority         = 1
  service_role_arn = aws_iam_role.ssm_mw_role.arn
  max_concurrency = "25%"
  max_errors      = "10%"
  
# Register the target for this specific task.
  targets {
    key    = "WindowTargetIds"
    values = [aws_ssm_maintenance_window_target.mwt_pay_app.id]
  }

# Parameters for the AWS-RunPatchBaseline command.
  task_invocation_parameters {
    run_command_parameters {
      parameter {
        name   = "Operation"
        values = ["Install"]
      }
    }
  }
}

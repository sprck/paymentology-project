# IAM Policy for the shared KMS Key.
# Root and Administrative permissions for Key
data "aws_iam_policy_document" "kms_key_policy" {
  statement {
    sid       = "EnableIAMUserPermissions"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.paymentology.account_id}:root"]
    }
  }  
## If sec account managed keys their identifier would be updated here instead of root again.
  statement {
    sid    = "AllowKeyAdmins"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.paymentology.account_id}:root"]
    }
    actions = [
      "kms:Create*", "kms:Describe*", "kms:Enable*", "kms:List*", "kms:Put*",
      "kms:Update*", "kms:Revoke*", "kms:Disable*", "kms:Get*", "kms:Delete*",
      "kms:TagResource", "kms:UntagResource", "kms:ScheduleKeyDeletion", "kms:CancelKeyDeletion"
    ]
    resources = ["*"]
  }
# Service permissions for the KMS Key.
  statement {
    sid    = "AllowServiceUsage"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com", "logs.amazonaws.com", "ssm.amazonaws.com","elasticloadbalancing.amazonaws.com", "autoscaling.amazonaws.com", "lambda.amazonaws.com", "delivery.logs.amazonaws.com", "s3.amazonaws.com", "cloudtrail.amazonaws.com",]
    }
    actions = [
      "kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*",
      "kms:GenerateDataKey*", "kms:DescribeKey"
    ]
    resources = ["*"]

  }

  statement {
    sid    = "AllowAutoScalingServiceLinkedRole"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.paymentology.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"
      ]
    }
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
      "kms:CreateGrant"
    ]
    resources = ["*"]
    condition {
      test     = "Bool"
      variable = "kms:GrantIsForAWSResource"
      values   = ["true"]
    }
  }

  statement {
    sid    = "AllowCloudWatchLogsUsage"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["logs.${data.aws_region.current.name}.amazonaws.com"]
    }
    actions = [
      "kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*",
      "kms:GenerateDataKey*", "kms:DescribeKey"
    ]
    resources = ["*"]
    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.paymentology.account_id}:log-group:*"]
    }
  }
}

# IAM policy document for the S3 logging bucket.
#1 Allow VPC Flow Logs to write logs.
data "aws_iam_policy_document" "s3_logs_pay_app" {
  statement {
    sid    = "AllowVPCFlowLogWriting"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.s3_logs_pay_app.arn}/*"]
   
  }

#2 Allow ALB Access Logs to write logs.
  statement {
    sid    = "AllowALBLogWriting"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["logdelivery.elasticloadbalancing.amazonaws.com"]
    }
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.s3_logs_pay_app.arn}/*"]

  }
  
# Allow CloudTrail to write logs.
  statement {
    sid    = "AllowCloudTrailLogWriting"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.s3_logs_pay_app.arn}/cloudtrail/AWSLogs/${data.aws_caller_identity.paymentology.account_id}/*"]

  }

# Allow CloudTrail to check the bucket's policy before delivering logs.
  statement {
    sid    = "AllowCloudTrailBucketCheck"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.s3_logs_pay_app.arn]
  }


#3 Allow CloudFront to write logs.
    statement {
    sid    = "AllowCloudFrontLogWriting"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.s3_logs_pay_app.arn}/cloudfront-logs/*"]

  }
}

# IAM Role for EC2 Instances
resource "aws_iam_role" "ec2_pay_app" {
  name = "${var.app_name}-ec2-role"

  # Policy that allows EC2 to assume this role.
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Action    = "sts:AssumeRole",
        Effect    = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-ec2-role"
    }
  )
}

# Attach the AWS managed policy for SSM access.
resource "aws_iam_role_policy_attachment" "ec2_ssm_pay_app" {
  role       = aws_iam_role.ec2_pay_app.name
  policy_arn = var.ec2_ssm_policy
}

# Attach the AWS managed policy for the CloudWatch agent.
resource "aws_iam_role_policy_attachment" "ec2_cloudwatch_pay_app" {
  role       = aws_iam_role.ec2_pay_app.name
  policy_arn = var.ec2_cloudwatch_policy
}

# Create an instance profile to attach the role to EC2 instances.
resource "aws_iam_instance_profile" "ec2_IP_pay_app" {
  name = "${var.app_name}-ec2-instance-profile"
  role = aws_iam_role.ec2_pay_app.name

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-ec2-instance-profile"
    }
  )
}

# IAM Role for API Gateway CloudWatch Logging
resource "aws_iam_role" "api_gw_logging_role" {
  name = "${var.app_name}-api-gw-logging-role"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = {
        Service = "apigateway.amazonaws.com"
      }
    }]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-api-gw-logging-role"
    }
  )
}
# IAM Policy for API Gateway CloudWatch Logging
resource "aws_iam_role_policy" "api_gw_logging_policy" {
  name = "${var.app_name}-api-gw-logging-policy"
  role = aws_iam_role.api_gw_logging_role.id

  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams",
        "logs:PutLogEvents",
        "logs:GetLogEvents",
        "logs:FilterLogEvents"
      ],
      Effect   = "Allow",
      Resource = "*"
    }]
  })
}

# --- IAM Role for SSM Maintenance Window ---
resource "aws_iam_role" "ssm_mw_role" {
  name = "${var.app_name}-ssm-mw-role"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = {
        Service = "ssm.amazonaws.com"
      }
    }]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-ssm-mw-role"
    }
  )
}
# Attach the AWS managed policy that grants necessary permissions for maintenance tasks.
resource "aws_iam_role_policy_attachment" "ssm_mw_policy_attachment" {
  role       = aws_iam_role.ssm_mw_role.name
  policy_arn = var.ssm_maintainance_role_arn
}

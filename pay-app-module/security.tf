# This data source gets the AWS-managed prefix list for CloudFront's edge servers.
data "aws_ec2_managed_prefix_list" "cloudfront_ipv4" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

# KMS Key for Encryption
resource "aws_kms_key" "pay_app_kms" {
  description             = "Shared KMS key for the Pay App"
  policy                  = data.aws_iam_policy_document.kms_key_policy.json
  deletion_window_in_days = 10
  enable_key_rotation     = true
  key_usage               = "ENCRYPT_DECRYPT"

  tags = var.tags
}

resource "aws_kms_alias" "pay_app_kms-alias" {
  name          = "alias/${var.kms_key_alias_name}"
  target_key_id = aws_kms_key.pay_app_kms.key_id
}

# ACM Certificate for HTTPS

resource "aws_acm_certificate" "cert_pay_app" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  tags = merge(
    var.tags,
    {
      Name = var.domain_name
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# DNS Validation Record - creates the CNAME record in Route 53 that ACM uses to prove domain ownership.

resource "aws_route53_record" "cert_validation_pay_app" {
  for_each = {
    for dvo in aws_acm_certificate.cert_pay_app.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.hz_pay_app.zone_id
}

# --- Certificate Validation -- tells Terraform to wait until the certificate has been successfully validated by ACM.
resource "aws_acm_certificate_validation" "cert_pay_app" {
  certificate_arn         = aws_acm_certificate.cert_pay_app.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation_pay_app : record.fqdn]
}


# Security Group for Application Load Balancer
resource "aws_security_group" "alb_sg_pay_app" {
  name        = "${var.app_name}-alb-sg"
  description = "Controls traffic for the Application Load Balancer"
  vpc_id      = aws_vpc.pay-demo-vpc.id

# Ingress Rule
  ingress {
    description = "Allow HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    prefix_list_ids = [data.aws_ec2_managed_prefix_list.cloudfront_ipv4.id]
  }
# Egress Rule

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-alb-sg"
    }
  )
}

# Security Group for Application Instances

resource "aws_security_group" "app_sg_pay_app" {
  name        = "${var.app_name}-app-sg"
  description = "Controls traffic for the application instances (EC2)"
  vpc_id      = aws_vpc.pay-demo-vpc.id

  # Ingress Rule: Allow traffic only from the ALB on the application port.
  # Egress Rule: Allow all outbound traffic-allows instances to reach the Internet through NAT Gateway.
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-app-sg"
    }
  )
}

  # Ingress Rule: Allow traffic only from the ALB and NLB on the application port.

resource "aws_security_group_rule" "app_from_alb" {
  type                     = "ingress"
  from_port                = var.app_port
  to_port                  = var.app_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb_sg_pay_app.id
  security_group_id        = aws_security_group.app_sg_pay_app.id
  description              = "Allow traffic from ALB"
}

resource "aws_security_group_rule" "app_from_nlb_subnets" {
  type              = "ingress"
  from_port         = var.app_port
  to_port           = var.app_port
  protocol          = "tcp"
  cidr_blocks       = [for s in aws_subnet.private-subnet-pay_app : s.cidr_block]
  security_group_id = aws_security_group.app_sg_pay_app.id
  description       = "Allow traffic from NLB subnets"
}


# NACLS
# Network ACL for Public Subnets
resource "aws_network_acl" "nacl_public_pay_app" {
  vpc_id = aws_vpc.pay-demo-vpc.id

# Inbound Rules
  ingress {
    rule_no    = 90
    protocol   = "-1"
    action     = "allow"
    cidr_block = "0.0.0.0/0"  # Allow all traffic from within VPC
    from_port  = 0
    to_port    = 0
  }
  
  ingress {
    rule_no     = 100
    protocol    = "tcp"
    action      = "allow"
    cidr_block  = "0.0.0.0/0"
    from_port   = 443 
    to_port     = 443
  }

  ingress {
    rule_no= 120
    protocol    = "tcp"
    action      = "allow"
    cidr_block  = "0.0.0.0/0"
    from_port   = 1024 
    to_port     = 65535
  }

# Outbound Rules
  egress {
    rule_no= 100
    protocol    = "-1" # Allow all outbound traffic
    action      = "allow"
    cidr_block  = "0.0.0.0/0"
    from_port   = 0
    to_port     = 0
  }

  tags = merge(var.tags, { Name = "${var.app_name}-public-nacl" })
}

# Network ACL for Private Subnets
resource "aws_network_acl" "nacl_private_pay_app" {
  vpc_id = aws_vpc.pay-demo-vpc.id

# Inbound Rules
  ingress {
    rule_no= 100
    protocol    = "-1"
    action      = "allow"
    cidr_block  = var.vpc_cidr_block
    from_port   = 0
    to_port     = 0
  }

# Outbound Rules
  egress {
    rule_no= 100
    protocol    = "-1" 
    action      = "allow"
    cidr_block  = "0.0.0.0/0"
    from_port   = 0
    to_port     = 0
  }

  tags = merge(var.tags, { Name = "${var.app_name}-private-nacl" })
}

# NACL Associations

resource "aws_network_acl_association" "public_nacl_assoc" {
  for_each       = aws_subnet.public-subnet-pay_app
  network_acl_id = aws_network_acl.nacl_public_pay_app.id
  subnet_id      = each.value.id
}

resource "aws_network_acl_association" "private_nacl_assoc" {
  for_each       = aws_subnet.private-subnet-pay_app
  network_acl_id = aws_network_acl.nacl_private_pay_app.id
  subnet_id      = each.value.id
}
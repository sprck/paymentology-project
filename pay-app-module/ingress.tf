data "aws_region" "current" {}

# Route 53 Public Hosted Zone 

resource "aws_route53_zone" "hz_pay_app" {
  name = var.domain_name

  tags = merge(
    var.tags,
    {
      Name = var.domain_name
    }
  )
}

# Route 53 Alias Record for CloudFront

resource "aws_route53_record" "domain_alias_pay_app" {
  zone_id = aws_route53_zone.hz_pay_app.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.cfn_pay_app.domain_name
    zone_id                = aws_cloudfront_distribution.cfn_pay_app.hosted_zone_id
    evaluate_target_health = false
  }
}


# CloudFront Distribution 

# Random string for the secret CloudFront header - creates a secret value that CloudFront will send to the ALB.
resource "random_string" "cf_secret_header" {
  length  = 32
  special = false
}


resource "aws_cloudfront_distribution" "cfn_pay_app" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${var.app_name} CloudFront Distribution"
  default_root_object = "index.html"
  price_class         = "PriceClass_100" 
 
  restrictions {
    geo_restriction {
      restriction_type = "none"
      locations = []
    }
  }
# Origin 1: Application Load Balancer
  origin {
    origin_id   = "${var.app_name}-alb-origin"
    domain_name = aws_lb.alb_pay_app.dns_name

# Add a secret header that the ALB can use to verify requests.
    custom_header {
      name  = "X-Origin-Verify"
      value = random_string.cf_secret_header.result
    }

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

# Origin 2: API Gateway
  origin {
    origin_id   = "${var.app_name}-api-gw-origin"
    domain_name = "${aws_api_gateway_rest_api.api-gw-pay-app.id}.execute-api.${data.aws_region.current.name}.amazonaws.com"
    origin_path = "/${var.api_gateway_stage_name}"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

# Default Cache Behavior (routes to ALB)
  default_cache_behavior {
    target_origin_id       = "${var.app_name}-alb-origin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

# Use a managed caching policy for server-side rendered content.
    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6" 
    origin_request_policy_id = "216adef6-5c7f-47e4-b989-5492eafa07d3"
  }

# API Cache Behavior (routes to API Gateway)
  ordered_cache_behavior {
    path_pattern           = "/api/*"
    target_origin_id       = "${var.app_name}-api-gw-origin"
    viewer_protocol_policy = "https-only"
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

# Use a managed policy that disables caching and forwards all parameters.
# origin request policy forwards all viewer headers and query strings.
    cache_policy_id = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
    origin_request_policy_id = "216adef6-5c7f-47e4-b989-5492eafa07d3"
  }

# Viewer Certificate and Domain Name
  aliases = [var.domain_name]

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.cert_pay_app.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

# Logging Configurations

   logging_config {
    include_cookies = false
    bucket          = aws_s3_bucket.s3_logs_pay_app.bucket_regional_domain_name
    prefix          = "cloudfront-logs/"
   }

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-cloudfront"
    }
  )
}


# VPC Link --Creates the private integration link between API Gateway and the Network Load Balancer.
resource "aws_api_gateway_vpc_link" "vpc-link-pay-app" {
  name        = "${var.app_name}-vpc-link"
  description = "VPC Link for API Gateway to NLB"
  target_arns = [aws_lb.nlb_pay_app.arn]

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-vpc-link"
    }
  )
}


# API Gateway REST API 

resource "aws_api_gateway_rest_api" "api-gw-pay-app" {
  name        = "${var.app_name}-api"
  
  description = "API Gateway for the Pay App"

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-api"
    }
  )
}

# API Gateway Proxy Resource --Creates a greedy path resource '{proxy+}' to catch all requests under the root.

resource "aws_api_gateway_resource" "api-gw-proxy-pay-app" {
  rest_api_id = aws_api_gateway_rest_api.api-gw-pay-app.id
  parent_id   = aws_api_gateway_rest_api.api-gw-pay-app.root_resource_id
  path_part   = "{proxy+}"
}

# API Gateway ANY Method -Creates a method to handle any HTTP verb (GET, POST, etc.) on the proxy resource.

resource "aws_api_gateway_method" "api-gw-any-method-pay-app" {
  rest_api_id   = aws_api_gateway_rest_api.api-gw-pay-app.id
  resource_id   = aws_api_gateway_resource.api-gw-proxy-pay-app.id
  http_method   = "ANY"
  authorization = "NONE"
  request_parameters = {
    "method.request.path.proxy" = true
  }
}

# API Gateway Integration -This connects the 'ANY' method to the NLB via the VPC Link.

resource "aws_api_gateway_integration" "api-gw-integration-pay-app" {
  rest_api_id             = aws_api_gateway_rest_api.api-gw-pay-app.id
  resource_id             = aws_api_gateway_resource.api-gw-proxy-pay-app.id
  http_method             = aws_api_gateway_method.api-gw-any-method-pay-app.http_method
  integration_http_method = "ANY"
  type                    = "HTTP_PROXY"
  connection_type         = "VPC_LINK"
  connection_id           = aws_api_gateway_vpc_link.vpc-link-pay-app.id

 # The URI for an NLB integration (http).  
  uri = "http://${aws_lb.nlb_pay_app.dns_name}:${var.app_port}/{proxy}"

  request_parameters = {
    "integration.request.path.proxy" = "method.request.path.proxy"
  }
}

# API Gateway Deployment --Deploys the API to make it callable.

resource "aws_api_gateway_account" "account_settings_pay_app" {
  cloudwatch_role_arn = aws_iam_role.api_gw_logging_role.arn
}

resource "aws_api_gateway_deployment" "api-gw-deployment-pay-app" {
  rest_api_id = aws_api_gateway_rest_api.api-gw-pay-app.id

# This trigger ensures that a new deployment is created whenever the integration changes.
  triggers = {
    redeployment = sha1(jsonencode(aws_api_gateway_integration.api-gw-integration-pay-app))
  }

  lifecycle {
    create_before_destroy = true
  }
}

# API Gateway Stage --Creates a named stage (e.g., 'v1') for the deployment.

resource "aws_api_gateway_stage" "api-gw-stage-pay_app" {
  deployment_id = aws_api_gateway_deployment.api-gw-deployment-pay-app.id
  rest_api_id   = aws_api_gateway_rest_api.api-gw-pay-app.id
  stage_name    = var.api_gateway_stage_name

  # Enable detailed access logging.
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.lg_api_gw_pay_app.arn
    # Use a standard JSON format for access logs.
    format = jsonencode({
      "requestId" : "$context.requestId",
      "ip" : "$context.identity.sourceIp",
      "caller" : "$context.identity.caller",
      "user" : "$context.identity.user",
      "requestTime" : "$context.requestTime",
      "httpMethod" : "$context.httpMethod",
      "resourcePath" : "$context.resourcePath",
      "status" : "$context.status",
      "protocol" : "$context.protocol",
      "responseLength" : "$context.responseLength"
    })
  }

  # This dependency ensures the account settings are configured before the stage is created.
  depends_on = [aws_api_gateway_account.account_settings_pay_app]
}

# Application Load Balancer (ALB)

resource "aws_lb" "alb_pay_app" {
  name               = "${var.app_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg_pay_app.id]
  subnets            = [for s in aws_subnet.public-subnet-pay_app : s.id]

  enable_deletion_protection = true

  access_logs {
    bucket = aws_s3_bucket.s3_logs_pay_app.id
    prefix = "alb"
    enabled = true
  }


  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-alb"
    }
  )
}

# Target Group

resource "aws_lb_target_group" "tarG_pay_app" {
  name        = "${var.app_name}-tg"
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.pay-demo-vpc.id
  target_type = "instance"

  health_check {
    enabled             = true
    path                = var.health_check_path
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-tg"
    }
  )
}

# HTTPS Listener
# Listens for traffic on port 443 and forwards it to the target group.

resource "aws_lb_listener" "https_pay_app" {
  load_balancer_arn = aws_lb.alb_pay_app.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.cert_pay_app.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tarG_pay_app.arn
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-https-listener"
    }
  )
}

# Network Load Balancer (NLB) for API Gateway Integration - Internal Lb from Api Gateway

resource "aws_lb" "nlb_pay_app" {
  name               = "${var.app_name}-nlb"
  internal           = true
  load_balancer_type = "network"
  subnets = [for s in aws_subnet.private-subnet-pay_app : s.id]

  enable_deletion_protection = true

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-nlb"
    }
  )
}

# NLB Target Group

resource "aws_lb_target_group" "nlb_tg_pay_app" {
  name        = "${var.app_name}-nlb-tg"
  port        = var.app_port
  protocol    = "TCP" 
  vpc_id      = aws_vpc.pay-demo-vpc.id
  target_type = "instance"

  health_check {
    enabled  = true
    protocol = "HTTP"
    path     = var.health_check_path
    port     = "traffic-port"
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-nlb-tg"
    }
  )
}

# NLB Listener 
resource "aws_lb_listener" "nlb_pay_app" {
  load_balancer_arn = aws_lb.nlb_pay_app.arn
  port              = var.app_port
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nlb_tg_pay_app.arn
  }
}
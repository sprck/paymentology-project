# --- Primary Outputs ---

output "application_url" {
  description = "The main URL for the deployed web application."
  value       = "https://${var.domain_name}"
}

output "api_endpoint" {
  description = "The base URL for the API."
  value       = "https://${var.domain_name}/api"
}

# --- IAM Outputs ---

output "ec2_iam_role_arn" {
  description = "The ARN of the IAM role for the EC2 instances."
  value       = module.pay_app.ec2_iam_role_arn
}

# --- Networking Outputs ---

output "vpc_id" {
  description = "The ID of the VPC."
  value       = module.pay_app.vpc_id
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC."
  value       = module.pay_app.vpc_cidr_block
}

output "public_subnet_ids" {
  description = "A list of the public subnet IDs."
  value       = module.pay_app.public_subnet_ids
}

output "private_subnet_ids" {
  description = "A list of the private subnet IDs."
  value       = module.pay_app.private_subnet_ids
}

output "nat_gateway_ids" {
  description = "A list of the NAT Gateway IDs."
  value       = module.pay_app.nat_gateway_ids
}

# --- Security Outputs ---

output "kms_key_arn" {
  description = "The ARN of the shared KMS key."
  value       = module.pay_app.kms_key_arn
}

output "certificate_arn" {
  description = "The ARN of the ACM certificate."
  value       = module.pay_app.certificate_arn
}

output "alb_security_group_id" {
  description = "The ID of the ALB security group."
  value       = module.pay_app.alb_security_group_id
}

output "app_security_group_id" {
  description = "The ID of the application security group."
  value       = module.pay_app.app_security_group_id
}

# --- Compute Outputs ---

output "launch_template_id" {
  description = "The ID of the EC2 Launch Template."
  value       = module.pay_app.launch_template_id
}

output "autoscaling_group_name" {
  description = "The name of the Auto Scaling Group."
  value       = module.pay_app.autoscaling_group_name
}

# --- Ingress Outputs ---

output "hosted_zone_ns_records" {
  description = "The Name Servers for the public hosted zone. Add these to your domain registrar."
  value       = module.pay_app.hosted_zone_ns_records
}

output "cloudfront_distribution_id" {
  description = "The ID of the CloudFront distribution."
  value       = module.pay_app.cloudfront_distribution_id
}

output "cloudfront_distribution_domain_name" {
  description = "The domain name of the CloudFront distribution."
  value       = module.pay_app.cloudfront_distribution_domain_name
}

output "api_gateway_invoke_url" {
  description = "The invoke URL for the API Gateway stage."
  value       = module.pay_app.api_gateway_invoke_url
}

output "alb_dns_name" {
  description = "The DNS name of the Application Load Balancer."
  value       = module.pay_app.alb_dns_name
}

output "nlb_arn" {
  description = "The ARN of the internal Network Load Balancer."
  value       = module.pay_app.nlb_arn
}

# --- Logging Outputs ---

output "log_bucket_id" {
  description = "The ID of the central S3 bucket for storing logs."
  value       = module.pay_app.log_bucket_id
}

# --- Monitoring Outputs ---

output "alerts_sns_topic_arn" {
  description = "The ARN of the SNS topic for alerts."
  value       = module.pay_app.alerts_sns_topic_arn
}
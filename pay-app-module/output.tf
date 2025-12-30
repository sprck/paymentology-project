#Output for Iam
output "ec2_iam_role_arn" {
  description = "The ARN of the IAM role for the EC2 instances."
  value       = aws_iam_role.ec2_pay_app.arn
}
#Output for Main.tf 

output "vpc_id" {
    description = "The ID of the VPC"
    value       = aws_vpc.pay-demo-vpc.id
  
}
output "vpc_cidr_block" {
    description = "CIDR block of VPC"
    value       = aws_vpc.pay-demo-vpc.cidr_block 
}
output "kms_key_arn" {
  description = "The ARN of the shared KMS key."
  value       = aws_kms_key.pay_app_kms.arn
}

output "log_bucket_id" {
  description = "The ID of the central S3 bucket for storing logs."
  value       = aws_s3_bucket.s3_logs_pay_app.id
}

#Output for Networking

output "public_subnet_ids" {
  description = "A list of the public subnet IDs, one for each AZ."
  value       = [for subnet in aws_subnet.public-subnet-pay_app : subnet.id]
}
output "private_subnet_ids" {
  description = "A list of the private subnet IDs, one for each AZ."
  value       = [for subnet in aws_subnet.private-subnet-pay_app : subnet.id]
}

output "nat_gateway_ids" {
  description = "A list of the NAT Gateway IDs, one for each AZ."
  value       = [for gw in aws_nat_gateway.nat-gw-pay : gw.id]
}

output "public_route_table_id" {
  description = "The ID of the public route table."
  value       = aws_route_table.public-route-table-pay.id
}

output "private_route_table_ids" {
  description = "A list of the private route table IDs, one for each AZ."
  value       = [for rt in aws_route_table.private-route-table-pay : rt.id]
}

#Output for Security

output "certificate_arn" {
  description = "The ARN of the ACM certificate for the ALB."
  value       = aws_acm_certificate.cert_pay_app.arn
}


output "alb_security_group_id" {
  description = "The ID of the Application Load Balancer security group."
  value       = aws_security_group.alb_sg_pay_app.id
}



output "app_security_group_id" {
  description = "The ID of the application instances security group."
  value       = aws_security_group.app_sg_pay_app.id
}

#Output for Compute

output "launch_template_id" {
  description = "The ID of the EC2 Launch Template."
  value       = aws_launch_template.lt-pay_app.id
}

output "autoscaling_group_name" {
  description = "The name of the Auto Scaling Group."
  value       = aws_autoscaling_group.asg-pay_app.name 
}

#Output for Ingress

output "hosted_zone_ns_records" {
  description = "The Name Servers for the public hosted zone. These must be added to the parent domain's NS records."
  value       = aws_route53_zone.hz_pay_app.name_servers
}

output "cloudfront_distribution_id" {
  description = "The ID of the CloudFront distribution."
  value       = aws_cloudfront_distribution.cfn_pay_app.id
}

output "cloudfront_distribution_domain_name" {
  description = "The domain name of the CloudFront distribution."
  value       = aws_cloudfront_distribution.cfn_pay_app.domain_name
}

output "cloudfront_secret_header_value" {
  description = "The secret value for the X-Origin-Verify header."
  value       = random_string.cf_secret_header.result
  sensitive   = true
}

output "api_gateway_invoke_url" {
  description = "The invoke URL for the API Gateway stage."
  value       = aws_api_gateway_stage.api-gw-stage-pay_app.invoke_url
}

output "alb_dns_name" {
  description = "The DNS name of the Application Load Balancer."
  value       = aws_lb.alb_pay_app.dns_name
}

output "alb_https_listener_arn" {
  description = "The ARN of the ALB's HTTPS listener."
  value       = aws_lb_listener.https_pay_app.arn
}

output "app_target_group_arn" {
  description = "The ARN of the application's target group."
  value       = aws_lb_target_group.tarG_pay_app.arn
}


output "nlb_arn" {
  description = "The ARN of the internal Network Load Balancer."
  value       = aws_lb.nlb_pay_app.arn
}

output "nlb_listener_arn" {
  description = "The ARN of the NLB listener."
  value       = aws_lb_listener.nlb_pay_app.arn
}

# Output for Monitoring

output "alerts_sns_topic_arn" {
  description = "The ARN of the SNS topic for performance and security alerts."
  value       = aws_sns_topic.sns_alerts_pay_app.arn
}

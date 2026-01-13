# --- General / Provider Variables ---

# variable "region" {
#   description = "The AWS region where resources will be deployed."
#   type        = string
# }

# --- Variables for Main.tf ---

variable "app_name" {
  description = "The base name for the application, used for naming resources."
  type        = string
}

variable "vpc_cidr_block" {
  description = "The CIDR block for the VPC."
  type        = string
}

variable "tags" {
  description = "A map of common tags to apply to all resources."
  type        = map(string)
}

variable "kms_key_alias_name" {
  description = "The alias for the KMS key."
  type        = string
}


# --- Variables for Networking ---

variable "availability_zones" {
  description = "A list of Availability Zones to deploy resources into."
  type        = list(string)
}

# --- Variables for Security ---

variable "app_port" {
  description = "The port the application instances will listen on."
  type        = number
}

# --- Variables for Compute ---

variable "instance_type" {
  description = "The EC2 instance type for the application."
  type        = string
}

variable "ami_id" {
  description = "The ID of the Amazon Machine Image (AMI) to use for the instances."
  type        = string
}

variable "asg_min_size" {
  description = "The minimum number of instances in the Auto Scaling Group."
  type        = number
}

variable "asg_max_size" {
  description = "The maximum number of instances in the Auto Scaling Group."
  type        = number
}

variable "asg_desired_capacity" {
  description = "The desired number of instances in the Auto Scaling Group."
  type        = number
}

# --- Variables for Ingress ---

variable "domain_name" {
  description = "The domain name for the application (e.g., app.example.com)."
  type        = string
}

variable "api_gateway_stage_name" {
  description = "The name for the API Gateway deployment stage (e.g., 'v1', 'prod')."
  type        = string
}

variable "health_check_path" {
  description = "The path for the load balancer to use for health checks."
  type        = string
}

# --- Variables for Monitoring ---

variable "alert_email" {
  description = "The email address to receive SNS alert notifications. You must confirm the subscription via email."
  type        = string
}
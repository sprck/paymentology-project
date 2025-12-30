# Variables for Main.tf 
variable "app_name" {
  description = "Name of Paymentology Application"
  type = string
  default = "pay-app"
}

variable "vpc_cidr_block" {
  description = "Cidr for paymentology vpc"
  type = string
  default = "10.0.0.0/16"
}

variable "tags" {
  description = "Common tags for all resources"
  type = map(string)
  default = {}
}

variable "kms_key_alias_name" {
  description = "KMS key for encryption at rest"
  type = string
  default = "pay-app-kms-key"
}



variable "ec2_ssm_policy" {
  description = "Policy for instance management with SSM"
  type = string
  default = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

variable "ec2_cloudwatch_policy" {
  description = "Policy for cloud watch logging"
  type = string
  default = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

variable "ssm_maintainance_role_arn" {
  description = "Policy for instance patching"
  type = string
  default = "arn:aws:iam::aws:policy/service-role/AmazonSSMMaintenanceWindowRole"
}

#variables for Networking
variable "availability_zones" {
  description = "Used AZs for Ca-central-1"
  type = list(string)
  default = ["ca-central-1a", "ca-central-1b"]
}

# Variables for Security
variable "app_port" {
  description = "The port the application instances will listen on."
  type        = number
  default     = 8080
}


# Variables for Compute


variable "instance_type" {
  description = "The EC2 instance type for the application."
  type        = string
  default     = "t3.micro"
}

variable "ami_id" {
  description = "The ID of the Amazon Machine Image (AMI) to use for the instances. Use a region-specific Amazon Linux 2023 AMI."
  type        = string
}

variable "asg_min_size" {
  description = "The minimum number of instances in the Auto Scaling Group."
  type        = number
  default     = 1
}

variable "asg_max_size" {
  description = "The maximum number of instances in the Auto Scaling Group."
  type        = number
  default     = 3
}

variable "asg_desired_capacity" {
  description = "The desired number of instances in the Auto Scaling Group."
  type        = number
  default     = 2
}


#Variables for Ingress

variable "domain_name" {
  description = "The domain name for the application"
  type        = string
  default = "pay-handson.click"
}


variable "api_gateway_stage_name" {
  description = "The name for the API Gateway deployment stage."
  type        = string
  default     = "v1"
}


variable "health_check_path" {
  description = "The path for the load balancer to use for health checks."
  type        = string
  default     = "/health"
}

# Variables for Monitoring
variable "alert_email" {
  description = "The email address to receive SNS alert notifications. You must confirm the subscription via email."
  type        = string
}


#Main
#region = "us-east-1"
app_name           = "pay-app"
vpc_cidr_block     = "10.0.0.0/16"
kms_key_alias_name = "pay-app-kms-key"
tags = {
  Project     = "Paymentology Demo"
 
}

# Variables for Networking 
availability_zones = ["us-east-1a", "us-east-1b"]

# Variables for Security 
app_port = 8080

# Variables for Compute 
instance_type = "t3.micro"

ami_id = "ami-068c0051b15cdb816"

asg_min_size         = 1
asg_max_size         = 3
asg_desired_capacity = 2

# Variables for Ingress 
domain_name            = "pay-handson.click"
api_gateway_stage_name = "v1"
health_check_path      = "/health"

# Variables for Monitoring 

alert_email = "sprck@gmail.com"
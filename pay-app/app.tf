locals {
  common_tags = merge(
    var.tags,
    {
      Environment = terraform.workspace
    }
  )
}

module "pay_app" {
  source = "../pay-app-module"

  app_name           = var.app_name
  vpc_cidr_block     = var.vpc_cidr_block
  tags               = local.common_tags
  kms_key_alias_name = var.kms_key_alias_name
  availability_zones = var.availability_zones
  app_port = var.app_port
  instance_type        = var.instance_type
  ami_id               = var.ami_id
  asg_min_size         = var.asg_min_size
  asg_max_size         = var.asg_max_size
  asg_desired_capacity = var.asg_desired_capacity
  domain_name            = var.domain_name
  api_gateway_stage_name = var.api_gateway_stage_name
  health_check_path      = var.health_check_path
  alert_email = var.alert_email
}
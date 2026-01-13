# EC2 Launch Template

resource "aws_launch_template" "lt-pay_app" {
  name_prefix   = "${var.app_name}-"
  image_id      = var.ami_id
  instance_type = var.instance_type
  
  user_data = base64encode(<<-EOF
${file("${path.module}/user_data.sh")}
EOF
)

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_IP_pay_app.name
  }

  network_interfaces {
    associate_public_ip_address = false 
    security_groups             = [aws_security_group.app_sg_pay_app.id]
  }

  block_device_mappings {
    device_name = "/dev/xvda" 
    ebs {
      volume_size           = 20
      volume_type           = "gp3"
       encrypted             = true
  #    kms_key_id            = aws_kms_key.pay_app_kms.arn
      delete_on_termination = true
    }
  }

# Enabled detailed monitoring for better metrics.

  monitoring {
    enabled = true
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.app_name}-launch-template"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# Auto Scaling Group ---

resource "aws_autoscaling_group" "asg-pay_app" {
  name_prefix = "${var.app_name}-asg-"

  vpc_zone_identifier = [for s in aws_subnet.private-subnet-pay_app : s.id]

# Scaling parameters.

  min_size             = var.asg_min_size
  max_size             = var.asg_max_size
  desired_capacity     = var.asg_desired_capacity
  health_check_type    = "ELB"
  health_check_grace_period = 300

  target_group_arns = [
    aws_lb_target_group.tarG_pay_app.arn,
    aws_lb_target_group.nlb_tg_pay_app.arn
    ]

# Using the launch template defined above.

  launch_template {
    id      = aws_launch_template.lt-pay_app.id
    version = "$Latest"
  }
# Automatic Rolling Updates

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
      instance_warmup        = 300
    }
    triggers = ["tag"]
  }


# Tagging instances created by this ASG.

  tag {
    key                 = "Name"
    value               = "${var.app_name}-instance"
    propagate_at_launch = true
  }
  tag {
    key                 = "PatchGroup"
    value               = "${var.app_name}-ec2-prod"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
  depends_on = [ aws_acm_certificate.cert_pay_app, aws_lb.alb_pay_app]
}


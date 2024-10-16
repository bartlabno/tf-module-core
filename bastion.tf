resource "aws_autoscaling_group" "bastion" {
  name                      = "bastion-asg-${local.suffix}"
  desired_capacity          = 1
  max_size                  = 1
  min_size                  = 1
  health_check_grace_period = 300
  health_check_type         = "EC2"
  force_delete              = true
  launch_configuration      = aws_launch_configuration.launch_conf[0].name
  vpc_zone_identifier       = module.vpc.private_subnets

  lifecycle {
    replace_triggered_by = [aws_launch_configuration.launch_conf]
  }

  count = var.create_bastion_host ? 1 : 0
}

resource "aws_launch_configuration" "launch_conf" {
  name                 = "bastion-lc-${local.suffix}"
  image_id             = data.aws_ami.ubuntu[0].id
  instance_type        = "t2.nano"
  security_groups      = [aws_security_group.bastion[0].id]
  iam_instance_profile = aws_iam_instance_profile.bastion_ec2_profile[0].id

  root_block_device {
    volume_type           = "standard"
    volume_size           = 10
    delete_on_termination = "true"
    encrypted             = "true"
  }

  user_data = <<-EOF
    #!/bin/bash
    sudo apt update
    sudo apt upgrade -y
    sudo apt install -y \
       awscli \
       curl \
       git \
       jq \
       python3-venv \
       rsync \
       socat \
       traceroute \
       wget
  EOF

  count = var.create_bastion_host ? 1 : 0
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  count = var.create_bastion_host ? 1 : 0
}
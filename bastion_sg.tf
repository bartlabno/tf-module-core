# Bastion has unrestricted outbound access
resource "aws_security_group" "bastion" {
  name        = "bastion-sg-${local.suffix}"
  description = "Security group for bastion host"
  vpc_id      = module.vpc.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name : "bastion-sg-${local.suffix}"
  }
  count = var.create_bastion_host ? 1 : 0
}

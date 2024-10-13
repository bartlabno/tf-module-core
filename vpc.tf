# See https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.13.0"

  name             = "env-${local.suffix}"
  cidr             = var.cidr
  default_vpc_name = "env-vpc-${local.suffix}"

  azs = data.aws_availability_zones.azs.names

  private_subnets       = var.private_subnets
  private_subnet_suffix = "prv-${local.suffix}"

  public_subnets       = var.public_subnets
  public_subnet_suffix = "pub-${local.suffix}"

  database_subnets           = var.database_subnets
  database_subnet_suffix     = "dbs-${local.suffix}"
  database_subnet_group_name = "dbsg-${local.suffix}"

  elasticache_subnets           = var.elasticache_subnets
  elasticache_subnet_suffix     = "els-${local.suffix}"
  elasticache_subnet_group_name = "elsg-${local.suffix}"

  # If doing NAT gateways, in order to save money (they're expensive), all the pre-prod environments get only one; prod gets one per AZ for redundancy
  enable_nat_gateway     = var.enable_nat_gateway
  single_nat_gateway     = (var.environment != "prod" || var.force_single_nat_gateway == true)
  one_nat_gateway_per_az = true # Not one per subnet

  # Apply standard naming
  default_security_group_name = "default-sg-${local.suffix}"
  nat_gateway_tags            = { Name = "ngw-${local.suffix}" }
  igw_tags                    = { Name = "igw-${local.suffix}" }
  nat_eip_tags                = { Name = "eip-${local.suffix}" }
  vpc_tags                    = { Name = "vpc-${local.suffix}" }

  # Adopt the VPC's default NACL and secure it (no access).
  manage_default_network_acl  = true
  default_network_acl_ingress = [local.deny_nacl_rule]
  default_network_acl_egress  = [local.deny_nacl_rule]
  default_network_acl_name    = "nacl-${local.suffix}"
  default_network_acl_tags = {
    Notes = "Default NACL for vpc-${local.suffix}, which denies all access. Do not use it."
  }

  # NACLs
  public_dedicated_network_acl = true
  public_inbound_acl_rules     = (length(local.public_ingress_nacl) > 0 || length(var.public_access_nacls_ingress) > 0) ? concat(local.public_ingress_nacl, var.public_access_nacls_ingress) : [local.deny_nacl_rule]
  public_outbound_acl_rules    = (length(local.public_egress_nacl) > 0 || length(var.public_access_nacls_egress) > 0) ? concat(local.public_egress_nacl, var.public_access_nacls_egress) : [local.deny_nacl_rule]
  public_acl_tags = {
    Name  = "pub-nacl-${local.suffix}",
    Notes = "Access allowed from internet (IPs may be restricted) on specific ports, and to private subnets"
  }

  private_dedicated_network_acl = true
  private_inbound_acl_rules     = (length(local.private_ingress_nacl) > 0) ? local.private_ingress_nacl : [local.deny_nacl_rule]
  private_outbound_acl_rules    = (length(local.private_egress_nacl) > 0) ? local.private_egress_nacl : [local.deny_nacl_rule]
  private_acl_tags = {
    Name  = "prv-nacl-${local.suffix}",
    Notes = "Access allowed from public subnets, and to database and elasticache subnets (if present) on specific ports"
  }

  database_dedicated_network_acl = true
  database_inbound_acl_rules     = (length(local.database_ingress_nacl) > 0) ? local.database_ingress_nacl : [local.deny_nacl_rule]
  database_outbound_acl_rules    = (length(local.database_egress_nacl) > 0) ? local.database_egress_nacl : [local.deny_nacl_rule]
  database_acl_tags = {
    Name  = "dbs-nacl-${local.suffix}",
    Notes = "Access allowed from private subnets on DB ports only. No outbound access."
  }

  elasticache_dedicated_network_acl = true
  elasticache_inbound_acl_rules     = (length(local.elasticache_ingress_nacl) > 0) ? local.elasticache_ingress_nacl : [local.deny_nacl_rule]
  elasticache_outbound_acl_rules    = (length(local.elasticache_egress_nacl) > 0) ? local.elasticache_egress_nacl : [local.deny_nacl_rule]
  elasticache_acl_tags = {
    Name  = "els-nacl-${local.suffix}",
    Notes = "Access allowed from private subnets on Elasticache ports only. No outbound access."
  }

  enable_dns_hostnames = true
}

data "aws_availability_zones" "azs" {}

locals {
  deny_nacl_rule = {
    "rule_no" : 1,
    "rule_number" : 1,
    "action" : "deny",
    "rule_action" : "deny",
    "protocol" : "-1",
    "cidr_block" : "0.0.0.0/0",
    "from_port" : 0,
    "to_port" : 0,
    "icmp_code" : 0,
    "icmp_type" : 0
  }

  #This rule allows the environment to talk to itself via the ALB which is in a public subnet, creating a route out from the private subnet and back in on itself through the public subnet.
  #/32 CIDR blocks are required to be applied to the NACL. This is an AWS requirement - a list of single IPs (published from the module) are amended into CIDRs with the below concat.
  reverse_public_access = concat(formatlist("%s/32", module.vpc.nat_public_ips), var.public_access_cidrs)

  # Generate public ingress NACL rules from the ports & CIDRs passed in
  public_ingress_nacl = concat(flatten(
    [for cidr in local.reverse_public_access :
      [for port in var.public_access_ports :
        {
          "rule_number" : 100 + (index(local.reverse_public_access, cidr) * length(var.public_access_ports)) + index(var.public_access_ports, port), # Jiggery-pokery to calculate unique rule numbers
          "rule_action" : "allow",
          "protocol" : "tcp",
          "cidr_block" : cidr
          "from_port" : port,
          "to_port" : port
        }
      ]
    ]),
    # Allow all traffic from the private subnet into the public subnet
    [for cidr in var.private_subnets :
      {
        "rule_number" : 200 + index(var.private_subnets, cidr)
        "rule_action" : "allow",
        "protocol" : "all",
        "cidr_block" : cidr
        "from_port" : 0,
        "to_port" : 0
    }],
    # Allow ephemeral tcp ports into the public subnets
    [
      {
        "rule_number" : 300
        "rule_action" : "allow",
        "protocol" : "tcp",
        "cidr_block" : "0.0.0.0/0"
        "from_port" : 1024,
        "to_port" : 65535
      }
    ]
  )

  # Public egress back out to anywhere, if we allow ingress (above) or if we have a NAT gateway
  public_egress_nacl = concat((length(local.public_ingress_nacl) > 0 || var.enable_nat_gateway) ? [
    {
      "rule_number" : 100
      "rule_action" : "allow",
      "protocol" : "all",
      "cidr_block" : "0.0.0.0/0"
      "from_port" : 0,
      "to_port" : 0
    }
    ] : [],
  )

  # Generate private ingress NACL rules
  # Trust all incoming traffic on the private subnets
  private_ingress_nacl = concat([
    {
      "rule_number" : 100,
      "rule_action" : "allow",
      "protocol" : "all",
      "cidr_block" : "0.0.0.0/0",
      "from_port" : 0,
      "to_port" : 0
    }]
  )

  # Trust all outgoing traffic from the private subnets
  private_egress_nacl = [
    {
      "rule_number" : 100,
      "rule_action" : "allow",
      "protocol" : "all",
      "cidr_block" : "0.0.0.0/0"
      "from_port" : 0,
      "to_port" : 0
    }
  ]


  # Generate database ingress NACL rules - db_access_ports from private subnets
  database_ingress_nacl = flatten(
    [for cidr in var.private_subnets :
      [for port in var.db_access_ports :
        {
          "rule_number" : 100 + (index(var.private_subnets, cidr) * length(var.db_access_ports)) + index(var.db_access_ports, port), # Jiggery-pokery to calculate unique rule numbers
          "rule_action" : "allow",
          "protocol" : "tcp",
          "cidr_block" : cidr
          "from_port" : port,
          "to_port" : port
        }
      ]
    ]
  )

  # Generate database egress NACL rules - ephemeral to private subnets
  # https://docs.aws.amazon.com/vpc/latest/userguide/vpc-network-acls.html#nacl-ephemeral-ports
  database_egress_nacl = [
    for cidr in var.private_subnets :
    {
      "rule_number" : 100 + index(var.private_subnets, cidr), # Jiggery-pokery to calculate unique rule numbers
      "rule_action" : "allow",
      "protocol" : "tcp",
      "cidr_block" : cidr
      "from_port" : 1024,
      "to_port" : 65535
    }
  ]

  # Generate elasticache ingress NACL rules - db_access_ports from private subnets
  elasticache_ingress_nacl = flatten(
    [for cidr in var.private_subnets :
      [for port in var.elasticache_access_ports :
        {
          "rule_number" : 100 + (index(var.private_subnets, cidr) * length(var.elasticache_access_ports)) + index(var.elasticache_access_ports, port), # Jiggery-pokery to calculate unique rule numbers
          "rule_action" : "allow",
          "protocol" : "tcp",
          "cidr_block" : cidr
          "from_port" : port,
          "to_port" : port
        }
      ]
    ]
  )

  # Generate elasticache egress NACL rules - ephemeral to private subnets
  elasticache_egress_nacl = [
    for cidr in var.private_subnets :
    {
      "rule_number" : 100 + index(var.private_subnets, cidr), # Jiggery-pokery to calculate unique rule numbers
      "rule_action" : "allow",
      "protocol" : "tcp",
      "cidr_block" : cidr
      "from_port" : 1024,
      "to_port" : 65535
    }
  ]
}
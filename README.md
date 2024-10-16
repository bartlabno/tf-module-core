# Terraform core module
Terraform core module for base network setup at AWS

## Purpose
I highly recommend to use separate module from your application layer to manage network. It will easily allow you to avoid mistakes applied against whole environment when you deploy application. Don't use monolith repositories to manage everything!

## What's included
- VPC creation
- Subnets creation
- NACL management

## TODO / in progress
- AWS Route53
- Bastion instance
- base IAM policies
- VPC endpoints
- AWS SES

### Variables
- `create_bastion_host`: If set to true (defaults to false), an EC2 bastion host is created, with useful tools installed. Access is via AWS Systems Manager (SSM) (not SSH). The Bastion host is created in a private subnet, with access to the DB and Elasticache subnets (if created), as well as full internet access. Note that if you create this, don't turn off enable_nat_gateway or the instance will not be able to download packages to configure itself, so you won't be able to connect to it.

### VPC related variables
- `cidr`: the CIDR for the VPC. This should be unique. A /16 is recommended.
- `private_subnets`, `public_subnets`, `database_subnets`, `elasticache_subnets`: CIDRs for each type of subnet. Must all be within cidr, and should be at least one per AZ in the region. May be omitted, in which case that kind of subnet won't be created. /24 or larger is strongly recommended (consider future use, as it is painful to add more IP space later). For understandability, aim to keep subnets of each type contiguous, and leave gaps for future expansion between the different types.
- `enable_nat_gateway`: Enable a NAT gateway (default = true). Pre-Prod environments get one (to keep costs down, at the expense of resilience), and Prod gets one per AZ.
- `public_access_ports` and `public_access_cidrs` (required): Create NACLs which allow access to public subnets from these IPs on those ports. The prod environment probably wants 0.0.0.0/0 for the CIDRs; pre-prod should almost certainly be locked down to trusted IPs. If either is an empty list, no NACLs are added.
- `public_access_nacls_ingress` and `public_access_nacls_egress`: Additional NACLs for public subnets, other than those created from public_access_cidrs and public_access_ports.
- `db_access_ports`: The ports used by services running in the DB subnet. Defaults to 3306 (MySQL).
- `elasticache_access_ports`: The ports used by services running in the DB subnet. Defaults to 11211 (Memcached).
- `force_single_nat_gateway`: Normally create one NAT Gateway per AZ in Production, for resilience. Use this to force a single NAT gateway even in prod if the resilience isn’t needed, to save costs.

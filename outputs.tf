output "vpc_id" {
  description = "The ID of the VPC for this environment"
  value       = module.vpc.vpc_id
}

output "subnet_ids" {
  description = "IDs of each of the types of subnet: public, private, database and elasticache"
  value = {
    public      = module.vpc.public_subnets
    private     = module.vpc.private_subnets
    database    = module.vpc.database_subnets
    elasticache = module.vpc.elasticache_subnets
  }
}

output "subnet_cidr_blocks" {
  description = "CIDR blocks of each of the types of subnet: public, private, database and elasticache"
  value = {
    public      = module.vpc.public_subnets_cidr_blocks
    private     = module.vpc.private_subnets_cidr_blocks
    database    = module.vpc.database_subnets_cidr_blocks
    elasticache = module.vpc.elasticache_subnets_cidr_blocks
  }
}

output "database_subnet_group_id" {
  description = "ID of the database subnet group"
  value       = module.vpc.database_subnet_group
}

output "elasticache_subnet_group_id" {
  description = "ID of the elasticache subnet group"
  value       = module.vpc.elasticache_subnet_group
}

output "natgw_ids" {
  description = "ID of the NAT gateway(s)"
  value       = module.vpc.natgw_ids
}

output "nat_public_ips" {
  description = "IPs of the NAT gateway(s)"
  value       = module.vpc.nat_public_ips
}
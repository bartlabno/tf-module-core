# Default variables
variable "tag_version" {}

variable "environment" {}

variable "project_name" {}

# VPC related variables
variable "cidr" {
  type        = string
  description = "The CIDR for the VPC."
}

variable "private_subnets" {
  type        = list(string)
  description = "CIDR(s) for private subnet(s) in the VPC"
}

variable "public_subnets" {
  type        = list(string)
  description = "CIDR(s) for public subnet(s) in the VPC"
}

variable "database_subnets" {
  type        = list(string)
  description = "CIDR(s) for database subnet(s) in the VPC (if required)"
  default     = []
}

variable "elasticache_subnets" {
  type        = list(string)
  description = "CIDR(s) for elasticache subnet(s) in the VPC (if required)"
  default     = []
}

variable "enable_nat_gateway" {
  type        = bool
  description = "Is a NAT gateway required? (Note: pre-prod gets 1 NAT gw and prod gets 1 per AZ)"
  default     = true
}

variable "force_single_nat_gateway" {
  type        = bool
  description = "Force a single NAT gateway in Production"
  default     = false
}
variable "public_access_ports" {
  type        = list(number)
  description = "Ports to allow to the public subnets (via NACLs). Defaults to 443, 80 only."
  default     = [443, 80]
}

variable "public_access_cidrs" {
  type        = list(string)
  description = "The CIDRs which can access public subnets on the public_access_ports (via NACLs). Strongly recommended to be office IPs only for pre-Prod environments."
}

variable "public_access_nacls_ingress" {
  type        = list(map(string))
  description = "Additional NACLs for public subnets. Start rule numbers from 1000."
  default     = []
}

variable "public_access_nacls_egress" {
  type        = list(map(string))
  description = "Additional NACLs for public subnets. Start rule numbers from 1000."
  default     = []
}

variable "db_access_ports" {
  type        = list(number)
  description = "Port(s) to allow from private subnets to database subnets (if present) (via NACLs). Defaults to 3306 (MySQL)."
  default     = [3306]
}

variable "elasticache_access_ports" {
  type        = list(number)
  description = "Port(s) to allow from private subnets to Elasticache subnets (if present) (via NACLs). Defaults to 11211 (Memcached)."
  default     = [11211]
}

# Create bastion
variable "create_bastion_host" {
  type        = bool
  description = "Create a bastion host for environment"
  default     = false
}
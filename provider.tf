terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.54.1"
    }
  }
}
provider "aws" {

  default_tags {
    tags = {
      version    = var.tag_version
      project    = var.project_name
      environmet = var.environment
      created_by = "terraform"
    }
  }
}
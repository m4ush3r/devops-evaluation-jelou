terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region     = "us-east-1"
  access_key = var.dev_user
  secret_key = var.dev_passw
}

module "vpc" {
  source = "./modules/vpc"
  
  vpc_cidr             = "10.0.0.0/16"
  public_subnet_cidr   = "10.0.1.0/24"
  private_subnet_cidr  = "10.0.2.0/24"
  availability_zone    = "us-east-1a"
  
  tags = {
    Environment = "dev"
    Project     = "user-management"
  }
}

module "security_groups" {
  source = "./modules/security"
  
  vpc_id = module.vpc.vpc_id
  
  tags = {
    Environment = "dev"
    Project     = "user-management"
  }
}

module "alb" {
  source = "./modules/alb"
  
  vpc_id              = module.vpc.vpc_id
  public_subnet_ids   = module.vpc.public_subnet_ids
  security_group_ids  = [module.security_groups.alb_security_group_id]
  
  tags = {
    Environment = "dev"
    Project     = "user-management"
  }
}

module "ecr" {
  source = "./modules/ecr"
  
  tags = {
    Environment = "dev"
    Project     = "user-management"
  }
}

module "rds" {
  source = "./modules/rds"
  
  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [module.security_groups.rds_security_group_id]
  
  tags = {
    Environment = "dev"
    Project     = "user-management"
  }
}

module "service_discovery" {
  source = "./modules/service-discovery"
  
  vpc_id = module.vpc.vpc_id
  
  tags = {
    Environment = "dev"
    Project     = "user-management"
  }
}

module "ecs" {
  source = "./modules/ecs"
  
  vpc_id                  = module.vpc.vpc_id
  subnet_ids              = module.vpc.private_subnet_ids
  security_group_ids      = [module.security_groups.ecs_security_group_id]
  db_endpoint             = module.rds.db_endpoint
  service_discovery_arn   = module.service_discovery.service_discovery_arn
  target_group_arn        = module.alb.target_group_arn
  
  tags = {
    Environment = "dev"
    Project     = "user-management"
  }
}

module "route53" {
  source = "./modules/route53"
  
  vpc_id                     = module.vpc.vpc_id
  service_internal_dns_name  = module.service_discovery.service_dns_name
  database_endpoint          = module.rds.db_endpoint
  
  tags = {
    Environment = "dev"
    Project     = "user-management"
  }
}
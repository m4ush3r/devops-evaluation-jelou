output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "rds_database_endpoint" {
  description = "RDS database direct endpoint"
  value       = module.rds.db_endpoint
  sensitive   = true
}

output "user_management_endpoint" {
  description = "Public user management service endpoint for applications"
  value       = module.route53.user_management_dns_name
}

output "database_endpoint" {
  description = "Public database endpoint for applications"
  value       = module.route53.database_dns_name
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ecs.cluster_id
}

output "internal_service_dns" {
  description = "Internal Cloud Map DNS (hidden from applications)"
  value       = module.service_discovery.service_dns_name
}

output "route53_zone_id" {
  description = "Route53 hosted zone ID for devops.test"
  value       = module.route53.hosted_zone_id
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer - Public access point"
  value       = module.alb.alb_dns_name
}

output "ecr_repository_url" {
  description = "ECR repository URL for pushing Docker images"
  value       = module.ecr.repository_url
}
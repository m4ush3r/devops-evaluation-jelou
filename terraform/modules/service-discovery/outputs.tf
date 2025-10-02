output "service_discovery_arn" {
  description = "ARN of the service discovery service"
  value       = aws_service_discovery_service.main.arn
}

output "service_discovery_namespace_id" {
  description = "ID of the service discovery namespace"
  value       = aws_service_discovery_private_dns_namespace.main.id
}

output "service_dns_name" {
  description = "Internal DNS name managed by Cloud Map (hidden)"
  value       = "user-management.devops.private"
}

output "public_service_dns_name" {
  description = "Public DNS name that applications should use"
  value       = "user-management.devops.test"
}

output "namespace_hosted_zone_id" {
  description = "Route53 hosted zone ID created by Cloud Map"
  value       = aws_service_discovery_private_dns_namespace.main.hosted_zone
}
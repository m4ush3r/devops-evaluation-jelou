output "hosted_zone_id" {
  description = "Route53 hosted zone ID for devops.test"
  value       = aws_route53_zone.devops_test.zone_id
}

output "user_management_dns_name" {
  description = "Public user management service DNS name"
  value       = aws_route53_record.user_management.fqdn
}

output "database_dns_name" {
  description = "Public database DNS name"
  value       = aws_route53_record.database.fqdn
}

output "zone_name_servers" {
  description = "Name servers for the hosted zone"
  value       = aws_route53_zone.devops_test.name_servers
}
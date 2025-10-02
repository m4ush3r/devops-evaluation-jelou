resource "aws_service_discovery_private_dns_namespace" "main" {
  name        = "devops.private"
  description = "Private service discovery namespace (hidden from applications)"
  vpc         = var.vpc_id

  tags = var.tags
}

resource "aws_service_discovery_service" "main" {
  name = "user-management"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }
  
  health_check_custom_config {
    failure_threshold = 1
  }

  tags = var.tags
}
variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "service_internal_dns_name" {
  description = "Internal DNS name from Cloud Map (e.g., user-management.devops.private)"
  type        = string
}

variable "database_endpoint" {
  description = "RDS database endpoint"
  type        = string
}

variable "tags" {
  description = "Tags to be applied to all resources"
  type        = map(string)
  default     = {}
}
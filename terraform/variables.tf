variable "dev_user" {
  description = "AWS access key for development environment"
  type        = string
  sensitive   = true
}

variable "dev_passw" {
  description = "AWS secret key for development environment"
  type        = string
  sensitive   = true
}
resource "aws_route53_zone" "devops_test" {
  name = "devops.test"
  
  vpc {
    vpc_id = var.vpc_id
  }

  tags = merge(var.tags, {
    Name = "devops.test Private Hosted Zone"
    Type = "Application Layer DNS"
  })
}


resource "aws_route53_record" "user_management" {
  zone_id = aws_route53_zone.devops_test.zone_id
  name    = "user-management.devops.test"
  type    = "CNAME"
  ttl     = 300
  records = [var.service_internal_dns_name]
}

resource "aws_route53_record" "database" {
  zone_id = aws_route53_zone.devops_test.zone_id
  name    = "database.devops.test"
  type    = "CNAME"
  ttl     = 300
  records = [var.database_endpoint]
}
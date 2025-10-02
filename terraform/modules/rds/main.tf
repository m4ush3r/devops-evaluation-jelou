resource "aws_db_subnet_group" "main" {
  name       = "user-management-db-subnet-group"
  subnet_ids = var.subnet_ids

  tags = merge(var.tags, {
    Name = "user-management-db-subnet-group"
  })
}

resource "aws_db_instance" "main" {
  identifier = "user-management-db"

  allocated_storage       = 20
  max_allocated_storage   = 100
  storage_type           = "gp2"
  storage_encrypted      = true

  engine         = "postgres"
  engine_version = "15.7"
  instance_class = "db.t3.micro"

  db_name  = "userdb"
  username = "postgres"
  password = "defaultpassword"

  vpc_security_group_ids = var.security_group_ids
  db_subnet_group_name   = aws_db_subnet_group.main.name

  multi_az               = true
  backup_retention_period = 7
  backup_window          = "07:00-09:00"
  maintenance_window     = "Sun:09:00-Sun:11:00"

  skip_final_snapshot = true
  deletion_protection = false

  tags = merge(var.tags, {
    Name = "user-management-db"
  })
}


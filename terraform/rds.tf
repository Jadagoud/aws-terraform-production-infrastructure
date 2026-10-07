resource "aws_db_subnet_group" "mysql" {
  name = "devops-mysql-subnet-group"

  subnet_ids = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id
  ]

  tags = {
    Name = "devops-mysql-subnet-group"
  }
}
resource "aws_db_instance" "mysql" {
  identifier = "devops-mysql"

  engine         = "mysql"
  engine_version = "8.0"

  instance_class      = "db.t3.micro"
  allocated_storage   = 20
  storage_type        = "gp3"
  storage_encrypted   = true
  publicly_accessible = false
  multi_az            = false
  deletion_protection = false
  skip_final_snapshot = true

  db_name  = "devops_app"
  username = "devopsadmin"
  password = "var.rds_password"

  db_subnet_group_name = aws_db_subnet_group.mysql.name

  vpc_security_group_ids = [
    aws_security_group.rds.id
  ]

  backup_retention_period = 7

  backup_window      = "03:00-04:00"
  maintenance_window = "sun:04:00-sun:05:00"

  tags = {
    Name = "devops-mysql"
  }
}

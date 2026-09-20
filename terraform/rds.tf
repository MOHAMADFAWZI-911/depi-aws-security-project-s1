resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "depi-sec-db-subnet-group"
  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  tags       = { Name = "depi-sec-db-subnet-group" }
}

resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "db_secret" {
  name = "depi-sec-db-password-${random_id.suffix.hex}"
}

resource "aws_secretsmanager_secret_version" "db_secret_version" {
  secret_id     = aws_secretsmanager_secret.db_secret.id
  secret_string = random_password.db_password.result
}

resource "aws_db_instance" "mysql_db" {
  identifier             = "depi-sec-rds-mysql"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  storage_type           = "gp3"
  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  
  username               = "admin"
  password               = random_password.db_password.result
  
  publicly_accessible    = false
  storage_encrypted      = true
  multi_az               = false
  skip_final_snapshot    = true
  deletion_protection    = false

  tags = { Name = "depi-sec-rds-mysql" }
}
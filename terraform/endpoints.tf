resource "aws_vpc_endpoint" "s3_gateway" {
  vpc_id            = aws_vpc.app_vpc.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private_rt.id]
}

resource "aws_security_group" "endpoint_sg" {
  name        = "depi-sec-endpoint-sg"
  description = "Security Group for Interface Endpoints"
  vpc_id      = aws_vpc.app_vpc.id
}

resource "aws_vpc_security_group_ingress_rule" "endpoint_https" {
  security_group_id = aws_security_group.endpoint_sg.id
  cidr_ipv4         = "10.0.0.0/16"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}

locals {
  ssm_endpoints = [
    "com.amazonaws.${var.region}.ssm",
    "com.amazonaws.${var.region}.ssmmessages",
    "com.amazonaws.${var.region}.ec2messages"
  ]
}

resource "aws_vpc_endpoint" "ssm_interfaces" {
  count               = length(local.ssm_endpoints)
  vpc_id              = aws_vpc.app_vpc.id
  service_name        = local.ssm_endpoints[count.index]
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  security_group_ids  = [aws_security_group.endpoint_sg.id]
  private_dns_enabled = true
}
# --- Tools VPC & Subnet ---

resource "aws_vpc" "tools_vpc" {
  cidr_block           = "10.1.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = { Name = "depi-sec-tools-vpc" }
}

resource "aws_subnet" "tools_private" {
  vpc_id                  = aws_vpc.tools_vpc.id
  cidr_block              = "10.1.1.0/24"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = false
  tags = { Name = "depi-sec-tools-a" }
}

resource "aws_route_table" "tools_rt" {
  vpc_id = aws_vpc.tools_vpc.id
  tags = { Name = "depi-sec-tools-rt" }
}

resource "aws_route_table_association" "tools_assoc" {
  subnet_id      = aws_subnet.tools_private.id
  route_table_id = aws_route_table.tools_rt.id
}

# --- VPC Peering Connection ---

resource "aws_vpc_peering_connection" "app_to_tools" {
  vpc_id      = aws_vpc.app_vpc.id
  peer_vpc_id = aws_vpc.tools_vpc.id
  auto_accept = true
  tags = { Name = "depi-sec-app-to-tools-peering" }
}

# --- Routing Updates ---

resource "aws_route" "app_to_tools_route" {
  route_table_id            = aws_route_table.private_rt.id
  destination_cidr_block    = "10.1.0.0/16"
  vpc_peering_connection_id = aws_vpc_peering_connection.app_to_tools.id
}

resource "aws_route" "tools_to_app_route" {
  route_table_id            = aws_route_table.tools_rt.id
  destination_cidr_block    = "10.0.0.0/16"
  vpc_peering_connection_id = aws_vpc_peering_connection.app_to_tools.id
}

# --- Security Group Updates for App VPC ---

resource "aws_vpc_security_group_ingress_rule" "app_allow_tools_http" {
  security_group_id = aws_security_group.app_sg.id
  cidr_ipv4         = "10.1.1.0/24"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "app_allow_tools_icmp" {
  security_group_id = aws_security_group.app_sg.id
  cidr_ipv4         = "10.1.1.0/24"
  from_port         = -1
  ip_protocol       = "icmp"
  to_port           = -1
}

# --- Tools Instance & Security Group ---

resource "aws_security_group" "tools_sg" {
  name        = "depi-sec-tools-sg"
  description = "Security Group for Tools Instance"
  vpc_id      = aws_vpc.tools_vpc.id
}

resource "aws_vpc_security_group_egress_rule" "tools_egress" {
  security_group_id = aws_security_group.tools_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_instance" "tools_monitor" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.tools_private.id
  vpc_security_group_ids      = [aws_security_group.tools_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name
  associate_public_ip_address = false

  tags = { Name = "depi-sec-tools-monitor" }
}

# --- VPC Endpoints for Tools VPC (To allow Session Manager without internet) ---
resource "aws_vpc_endpoint" "tools_ssm_interfaces" {
  count               = length(local.ssm_endpoints)
  vpc_id              = aws_vpc.tools_vpc.id
  service_name        = local.ssm_endpoints[count.index]
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.tools_private.id]
  security_group_ids  = [aws_security_group.tools_sg.id]
  private_dns_enabled = true
}
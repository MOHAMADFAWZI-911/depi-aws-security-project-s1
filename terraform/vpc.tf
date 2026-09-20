resource "aws_vpc" "app_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "depi-sec-app-vpc"
  }
}

# Public Subnets
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.app_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.region}a"
  tags = { Name = "depi-sec-public-a" }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.app_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.region}b"
  tags = { Name = "depi-sec-public-b" }
}

# Private Subnets
resource "aws_subnet" "private_a" {
  vpc_id                  = aws_vpc.app_vpc.id
  cidr_block              = "10.0.11.0/24"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = false
  tags = { Name = "depi-sec-private-a" }
}

resource "aws_subnet" "private_b" {
  vpc_id                  = aws_vpc.app_vpc.id
  cidr_block              = "10.0.12.0/24"
  availability_zone       = "${var.region}b"
  map_public_ip_on_launch = false
  tags = { Name = "depi-sec-private-b" }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.app_vpc.id
  tags = { Name = "depi-sec-igw" }
}

# Public Route Table & Routes
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.app_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "depi-sec-public-rt" }
}

resource "aws_route_table_association" "public_a_assoc" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_b_assoc" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public_rt.id
}

# Private Route Table (No Internet Route)
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.app_vpc.id
  tags = { Name = "depi-sec-private-rt" }
}

resource "aws_route_table_association" "private_a_assoc" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_b_assoc" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private_rt.id
}
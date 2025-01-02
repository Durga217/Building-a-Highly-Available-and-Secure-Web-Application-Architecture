provider "aws" {
  region = "ap-south-1"
}
# Variables
variable "vpc_cidr_1" { default = "10.0.0.0/16" }
variable "vpc_cidr_2" { default = "10.1.0.0/16" }
variable "public_subnet_cidrs" {
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}
variable "private_subnet_cidrs" {
  default = ["10.1.1.0/24", "10.1.2.0/24"]
}
# VPC 1: Web Application
resource "aws_vpc" "vpc_1" {
  cidr_block = var.vpc_cidr_1
  tags = {
    Name = "VPC1-WebApp"
  }
}
resource "aws_subnet" "public_subnets" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.vpc_1.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name = "Public-Subnet-${count.index + 1}"
  }
}
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc_1.id
  tags = {
    Name = "VPC1-InternetGateway"
  }
}
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc_1.id
  tags = {
    Name = "PublicRouteTable"
  }
}
resource "aws_route" "default_route" {
  route_table_id         = aws_route_table.public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}
resource "aws_route_table_association" "public_association" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.public_route_table.id
}
# VPC 2: Database
resource "aws_vpc" "vpc_2" {
  cidr_block = var.vpc_cidr_2
  tags = {
    Name = "VPC2-Database"
  }
}
resource "aws_subnet" "private_subnets" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.vpc_2.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name = "Private-Subnet-${count.index + 1}"
  }
}
# VPC Peering
resource "aws_vpc_peering_connection" "vpc_peering" {
  vpc_id        = aws_vpc.vpc_1.id
  peer_vpc_id   = aws_vpc.vpc_2.id
  auto_accept   = true
  tags = {
    Name = "VPC-Peering"
  }
}
resource "aws_route" "peering_route_vpc1" {
  count                  = length(var.private_subnet_cidrs)
  route_table_id         = aws_route_table.public_route_table.id
  destination_cidr_block = aws_vpc.vpc_2.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.vpc_peering.id
}
resource "aws_route" "peering_route_vpc2" {
  count                  = length(var.private_subnet_cidrs)
  route_table_id         = aws_route_table.private_route_table.id
  destination_cidr_block = aws_vpc.vpc_1.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.vpc_peering.id
}
# Security Groups
resource "aws_security_group" "web_sg" {
  vpc_id = aws_vpc.vpc_1.id
  tags = {
    Name = "Web-SG"
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_security_group" "db_sg" {
  vpc_id = aws_vpc.vpc_2.id
  tags = {
    Name = "DB-SG"
  }
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = [aws_security_group.web_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
# RDS Instance in Private Subnet
resource "aws_db_instance" "rds_instance" {
  allocated_storage    = 20
  engine               = "mysql"
  instance_class       = "db.t3.micro"
  name                 = "webappdb"
  username             = "admin"
  password             = "securepassword123"
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  db_subnet_group_name = aws_db_subnet_group.db_subnet_group.name
}
resource "aws_db_subnet_group" "db_subnet_group" {
  name        = "db-subnet-group"
  description = "Database subnet group"
  subnet_ids  = aws_subnet.private_subnets[*].id
}

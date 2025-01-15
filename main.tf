provider "aws" {
  region = var.instance_region
}
locals {
  env = terraform.workspace
}

# Create a VPC
resource "aws_vpc" "myvpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "${local.env}-vpc"
  }
}

# Create a public subnet in the VPC
resource "aws_subnet" "PublicSubnet" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  tags = {
    Name = "${local.env}-public-subnet"
  }
}

# Create a private subnet in the VPC
resource "aws_subnet" "PrivSubnet" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = false
  tags = {
    Name = "${local.env}-private-subnet"
  }
}

# Create a Internet Gate Way
resource "aws_internet_gateway" "myIG" {
  vpc_id = aws_vpc.myvpc.id
  tags = {
    Name = "${local.env}-igw"
  }
}
resource "aws_eip" "nat_eip" {
  tags = {
    Name = "${local.env}-eip"
  }
}

# create a NAT Gate Way
resource "aws_nat_gateway" "myNAT" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.PublicSubnet.id
  tags = {
    Name = "${local.env}-NAT"
  }
}

## create 2 Route tables
# create public route table
resource "aws_route_table" "public_RT" {
  vpc_id = aws_vpc.myvpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.myIG.id
  }
  tags = {
    Name = "${local.env}-public_RT"
  }
}

# create a private route table
resource "aws_route_table" "private_RT" {
  vpc_id = aws_vpc.myvpc.id
  route {
    nat_gateway_id = aws_nat_gateway.myNAT.id
    cidr_block     = "0.0.0.0/0"
  }
  tags = {
    Name = "${local.env}-private_RT"
  }
}

# associate public RT to public subnet
resource "aws_route_table_association" "public_association_RT" {
  subnet_id      = aws_subnet.PublicSubnet.id
  route_table_id = aws_route_table.public_RT.id

}

# associate Private RT to Private subnet
resource "aws_route_table_association" "private_association_Rt" {
  subnet_id      = aws_subnet.PrivSubnet.id
  route_table_id = aws_route_table.private_RT.id
}

## create 2 security groups for instances
resource "aws_security_group" "jenkins_sg" {
  name        = "jenkins-sg"
  description = "Security group for Jenkins instance"
  vpc_id      = aws_vpc.myvpc.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Jenkins"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name        = "${local.env}-security-group"
    Environment = "Test"
  }
}

## Launch instances
# Create Jenkins EC2 instance in the public subnet
  resource "aws_instance" "four" {
  ami                    = var.instance_ami
  instance_type          = var.instance_type
  count                  = var.instance_count
  subnet_id              = aws_subnet.PrivSubnet.id
  vpc_security_group_ids = [aws_security_group.jenkins_sg.id]

  tags = {
    Name = var.instance_name
  }
}

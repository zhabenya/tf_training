variable "aws_region" {
  description = "AWS region"
  default = "us-east-1"
  type = string
}
variable "aws_av_zone" {
  description = "AWS availability zone"
  type = string
}
variable "subnet_prefix" {}

provider "aws" {
  region = var.aws_region
  access_key = "access_key"
  secret_key = "secret_key"
}

resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "tania_vpc"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "tania_gw"
  }
}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "tania_rt"
  }
}

resource "aws_subnet" "subnet-1" {
  cidr_block = var.subnet_prefix[0].cidr_block
  vpc_id = aws_vpc.vpc.id
  availability_zone = var.aws_av_zone

  tags = {
    Name = var.subnet_prefix[0].name
  }
}

resource "aws_subnet" "subnet-2" {
  cidr_block = var.subnet_prefix[1].cidr_block
  vpc_id = aws_vpc.vpc.id
  availability_zone = var.aws_av_zone

  tags = {
    Name = var.subnet_prefix[1].name
  }
}

resource "aws_route_table_association" "a" {
  subnet_id = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_security_group" "allow_web" {
  name = "allow_web_traffic"
  description = "Allow Web traffic"
  vpc_id = aws_vpc.vpc.id

  ingress {
    description = "HTTPS"
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = [
      "0.0.0.0/0"]
  }
  ingress {
    description = "HTTP"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = [
      "0.0.0.0/0"]
  }
  ingress {
    description = "SSH"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = [
      "0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [
      "0.0.0.0/0"]
  }

  tags = {
    Name = "allow_web"
  }
}

resource "aws_network_interface" "web-server-ni" {
  subnet_id = aws_subnet.subnet-1.id
  private_ips = [
    "10.0.1.50"]
  security_groups = [
    aws_security_group.allow_web.id]
}

resource "aws_eip" "one" {
  vpc = true
  network_interface = aws_network_interface.web-server-ni.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [
    aws_internet_gateway.gw]
}

output "server_public_ip" {
  value = aws_eip.one.public_ip
}

resource "aws_instance" "web-server-instance" {
  ami = "ami-0885b1f6bd170450c"
  instance_type = "t2.micro"
  availability_zone = var.aws_av_zone
  key_name = "tania_terraform_test"

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.web-server-ni.id
  }

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install apache2 -y
              sudo systemctl start apache2
              sudo bash -c 'echo the first shiny web server > /var/www/html/index.html'
              EOF

  tags = {
    Name = "tania_ws"
  }
}
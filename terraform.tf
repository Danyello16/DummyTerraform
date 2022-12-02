terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
    region = "us-east-1"
    access_key = "ASIASG7K3CRI6QY546BQ"
    secret_key = "n1dKfQX8zNxZPSb3hz5zKkhFyHHbuTIdCmOcp+0Z"
    #session_
    token = "FwoGZXIvYXdzEI7//////////wEaDNIOIoQHz5d3EwKqcCLBAUFme63pBdQeKml5uhz49VOBU4WYVaTI6ChikwqCkza92Cm9hNudMy3Q2xERy91+FvyTzJleaHMxFsdQnuF4KcVj7kG8fjsoEoTg5bjMc21GbuPZGBkbUgK+8RF4pV9ksVD+OJq4hzwH9V0YGFJogOT9i4q+eLev+P4gS8FrYJXlWe7SWK97loew4C5710eiB/1PXcMuyTLS+LGfKq4xDVBO9U6KmhgUTXE8LWwHR0wB1RimkoHkFj8Iw2Ok+oq7m3Uog62knAYyLYMF5HEfucRHayX3SxvQyhG5CNMnQKTqTqJsjSlIaw07GYkEEsd9V5yBnsfZLQ=="
}

#Created my own VPC
resource "aws_vpc" "main" {
  cidr_block       = "192.168.0.0/23"

  tags = {
    Name = "main"
  }
}

#Created an Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "gw_main"
  }
}

#Created a custom Route Table
resource "aws_route_table" "route_table" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "allow_all"
  }
}


#Created a subnet
resource "aws_subnet" "subnet_1" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "192.168.0.0/24"

  tags = {
    Name = "subnet_1"
  }
}

#Associated subnet with Route Table
resource "aws_route_table_association" "rt_associate" {
  subnet_id      = aws_subnet.subnet_1.id
  route_table_id = aws_route_table.route_table.id
}


#Create Security Group
resource "aws_security_group" "security_group" {
  name        = "allow_https/s"
  description = "Allow HTTP/s"
  vpc_id      = aws_vpc.main.id

  #Allow income HTTPS
  ingress {
    description      = "HTTPS from VPC"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  #Allow income HTTP
  ingress {
    description      = "HTTP from VPC"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  #Allow outgoing All
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_https"
  }
}

#Created a Network Interface with an IP in the subnet (the first IP address)
resource "aws_network_interface" "nw_interface" {
  subnet_id       = aws_subnet.subnet_1.id
  security_groups = [aws_security_group.security_group.id]
  count = 4

}

#Assigned an Elastic IP for the Instance
resource "aws_eip" "lb" {
  instance   = element(aws_instance.web.*.id, count.index)
  count = 4
  vpc      = true
}

#Defining AMI for the Instance that will be run
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

#Starting EC2 instance with the website running
resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"

  user_data = <<-EOF
    #!/bin/bash
    sudo apt-get update -y
    sudo apt-get install -y apache2
    sudo systemctl start apache2
    sudo systemctl enable apache2
    echo "<h1>Hello World</h1>" | sudo tee /var/www/html/index.html
  EOF


  # Creates four identical aws ec2 instances
  count = 4  

  network_interface {
    device_index            = 0
    network_interface_id    = aws_network_interface.nw_interface[count.index].id
  }

  tags = {
    Name = "my-machine-${count.index}"
  }
}


#Output the public IP of the instance
output "instance_ip" {
  value = aws_instance.web[*].public_ip
}


#Output the public IP of the instance
output "instance_dns" {
  value = aws_eip.lb[*].public_dns
}

# Provider configuration
provider "aws" {
  region = "us-east-1"
}

# VPC
resource "aws_vpc" "main_vpc" {
  cidr_block           = "172.20.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Name    = "lksvpc"
    Type    = "LKS"
    SubType = "Modul2"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main_vpc.id
  
  tags = {
    Name = "lksigw"
  }
}

# Public Subnets
resource "aws_subnet" "public_subnet_1a" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "172.20.0.0/25"
  availability_zone = "us-east-1a"
  
  tags = {
    Name    = "lks-public-1a"
    Type    = "LKS"
    SubType = "Modul2"
  }
}

resource "aws_subnet" "public_subnet_1b" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "172.20.0.128/25"
  availability_zone = "us-east-1b"
  
  tags = {
    Name    = "lks-public-1b"
    Type    = "LKS"
    SubType = "Modul2"
  }
}

# Private Subnets
resource "aws_subnet" "private_subnet_1a" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "172.20.1.0/26"
  availability_zone = "us-east-1a"
  
  tags = {
    Name    = "lks-private-1a"
    Type    = "LKS"
    SubType = "Modul2"
  }
}

resource "aws_subnet" "private_subnet_1b" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "172.20.1.64/26"
  availability_zone = "us-east-1b"
  
  tags = {
    Name    = "lks-private-1b"
    Type    = "LKS"
    SubType = "Modul2"
  }
}

# EIP for NAT Gateway
resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

# NAT Gateway
resource "aws_nat_gateway" "main_ngw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet_1a.id
  
  tags = {
    Name = "natgw"
  }
  
  depends_on = [aws_internet_gateway.main_igw]
}

# Route Tables
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main_vpc.id
  
  tags = {
    Name = "lkspublic"
  }
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main_vpc.id
  
  tags = {
    Name = "lksprivate"
  }
}

# Routes
resource "aws_route" "public_route" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main_igw.id
}

resource "aws_route" "private_route" {
  route_table_id         = aws_route_table.private_rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main_ngw.id
}

# Route Table Associations
resource "aws_route_table_association" "public_1a" {
  subnet_id      = aws_subnet.public_subnet_1a.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_1b" {
  subnet_id      = aws_subnet.public_subnet_1b.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "private_1a" {
  subnet_id      = aws_subnet.private_subnet_1a.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_1b" {
  subnet_id      = aws_subnet.private_subnet_1b.id
  route_table_id = aws_route_table.private_rt.id
}

# Security Groups
resource "aws_security_group" "lb_sg" {
  name        = "LoadBalancerSecurity"
  description = "Enable HTTP and HTTPS access via port 80 and 443"
  vpc_id      = aws_vpc.main_vpc.id
  
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    from_port   = 443
    to_port     = 443
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
    Name = "SG-LB"
  }
}

resource "aws_security_group" "instance_sg" {
  name        = "InstanceSecurity"
  description = "Enable access via port 3000 from Instance to the Internal Network"
  vpc_id      = aws_vpc.main_vpc.id
  
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["175.20.0.0/16"]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "SG-Apps"
  }
}

# EC2 Instances
resource "aws_instance" "web_server_1a" {
  ami                    = "ami-01eccbf80522b562b"
  instance_type          = "t3.small"
  subnet_id              = aws_subnet.private_subnet_1a.id
  vpc_security_group_ids = [aws_security_group.instance_sg.id]
  
  user_data = <<-EOF
    #!/bin/bash -xe
    yum update -y
    curl -fsSL https://rpm.nodesource.com/setup_16.x | sudo bash - 
    sudo yum install -y nodejs
    yum install git -y
    git clone https://github.com/handipradana/chartiot2023
    cd chartiot2023
    npm install
    cat <<EOT > .env 
    AWS_ACCESS_KEY=AKIAVK7O2PPCXEMCRDXV
    AWS_SECRET_ACCESS_KEY=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
    EOT
    npm run start-prod
  EOF
  
  tags = {
    Name = "lksapp1a"
  }
}

resource "aws_instance" "web_server_1b" {
  ami                    = "ami-01eccbf80522b562b"
  instance_type          = "t3.small"
  subnet_id              = aws_subnet.private_subnet_1b.id
  vpc_security_group_ids = [aws_security_group.instance_sg.id]
  
  user_data = <<-EOF
    #!/bin/bash -xe
    yum update -y
    curl -fsSL https://rpm.nodesource.com/setup_16.x | sudo bash - 
    sudo yum install -y nodejs
    yum install git -y
    git clone https://github.com/handipradana/chartiot2023
    cd chartiot2023
    npm install
    cat <<EOT > .env 
    AWS_ACCESS_KEY=AKIAVK7O2PPCXEMCRDXV
    AWS_SECRET_ACCESS_KEY=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
    EOT
    npm run start-prod
  EOF
  
  tags = {
    Name = "lksapps1b"
  }
}

# ALB Target Group
resource "aws_lb_target_group" "app_tg" {
  name     = "lks-tg"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = aws_vpc.main_vpc.id
  
  health_check {
    interval            = 120
    path                = "/"
    port                = "3000"
    protocol            = "HTTP"
    timeout             = 60
    healthy_threshold   = 3
    unhealthy_threshold = 2
  }
}

# Target Group Attachments
resource "aws_lb_target_group_attachment" "tg_attach_1a" {
  target_group_arn = aws_lb_target_group.app_tg.arn
  target_id        = aws_instance.web_server_1a.id
  port             = 3000
}

resource "aws_lb_target_group_attachment" "tg_attach_1b" {
  target_group_arn = aws_lb_target_group.app_tg.arn
  target_id        = aws_instance.web_server_1b.id
  port             = 3000
}

# Application Load Balancer
resource "aws_lb" "app_lb" {
  name               = "lks-public-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]
  subnets            = [aws_subnet.public_subnet_1a.id, aws_subnet.public_subnet_1b.id]
  ip_address_type    = "ipv4"
}

# ALB Listener
resource "aws_lb_listener" "app_listener" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = 80
  protocol          = "HTTP"
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

# Outputs
output "vpc_id" {
  description = "Creation of lksvpc"
  value       = aws_vpc.main_vpc.id
}

output "elb_dns_name" {
  description = "Load Balancer DNS"
  value       = aws_lb.app_lb.dns_name
}

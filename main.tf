resource "aws_vpc" "major" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "main_vpc"
  }
}

# public subnet 1 and 2 for ALB

resource "aws_subnet" "public_subnet" {
  vpc_id     = aws_vpc.major.id
  cidr_block = "10.0.0.0/23"
  availability_zone = "us-east-1a"

  tags = {
    Name = "public-subnet"
  }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id     = aws_vpc.major.id
  cidr_block = "10.0.2.0/23"
  availability_zone = "us-east-1b"

  tags = {
    Name = "public-subnet_2"
  }
}

# Private subnet 1 and 2 for EC2 in Target Group

resource "aws_subnet" "private_subnet" {
  vpc_id     = aws_vpc.major.id
  cidr_block = var.private_subnet_cidr
  availability_zone = "us-east-1a"

  tags = {
    Name = "private-subnet"
  }
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id     = aws_vpc.major.id
  cidr_block = var.private_subnet_cidr_2
  availability_zone = "us-east-1b"

  tags = {
    Name = "private-subnet_2"
  }
}
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.major.id

  tags = {
    Name = "main-gw"
  }
}

resource "aws_route_table" "main-igw-route" {
  vpc_id = aws_vpc.major.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "main-route"
  }
}

resource "aws_route_table_association" "public_subnet" {
  subnet_id         = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.main-igw-route.id
}

resource "aws_route_table_association" "public_subnet_2" {
  subnet_id         = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.main-igw-route.id
}

# creation of eip

resource "aws_eip" "for_nat" {
    domain   = "vpc"
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.for_nat.id
  subnet_id     = aws_subnet.public_subnet.id

  tags = {
    Name = "gw NAT"
  }
}

resource "aws_route_table" "private_subnet" {
  vpc_id = aws_vpc.major.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "private_subnet_route"
  }
}

resource "aws_route_table_association" "private_subnet" {
  subnet_id         = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_subnet.id
}

resource "aws_route_table_association" "private_subnet_2" {
  subnet_id         = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private_subnet.id
}

resource "aws_security_group" "securi_group" {
  name        = "securi_group"
  description = "Allow HTTP and HTTPS traffic"
  vpc_id      = aws_vpc.major.id

  tags = {
    Name = "securi_group"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_tls_ipv4" {
  security_group_id = aws_security_group.securi_group.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}

resource "aws_vpc_security_group_ingress_rule" "allow_http_ipv4" {
  security_group_id = aws_security_group.securi_group.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.securi_group.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

# Database
resource "aws_db_subnet_group" "database_subnet_group" {
  name       = "database_subnet"
  subnet_ids = [
    aws_subnet.private_subnet.id,
    aws_subnet.private_subnet_2.id
  ]

  tags = {
    Name = "RDS Private Subnet"
  }
}

# Security group for the RDS instance
resource "aws_security_group" "rds" {
  name        = "rds-sg"
  description = "Allow MySQL access from EC2 instances"
  vpc_id      = aws_vpc.major.id

  ingress {
    description     = "Allow MySQL from EC2 SGs"
    from_port       = var.rds_port
    to_port         = var.rds_port
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_asg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "rds-security-group"
  }
}


# db instance

resource "aws_db_instance" "rds_instance" {
  allocated_storage    = 20
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = "db.t3.micro" 
  username             = var.db_username
  password             = var.db_password
  parameter_group_name = "default.mysql8.0"
  skip_final_snapshot  = true
  db_subnet_group_name = aws_db_subnet_group.database_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  tags = {
    Name = "MyDBInstance"
  }
}

resource "aws_lb" "load_balancer" {
  name               = "main-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.securi_group.id]
  subnets            = [aws_subnet.public_subnet.id, aws_subnet.public_subnet_2.id]

  tags = {
    Name = "main-lb"
  }
}

# Listener for the ALB on port 80
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.load_balancer.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group.arn
  }
}

# Target Group for ALB forwarding HTTP to instances on port 80
resource "aws_lb_target_group" "target_group" {
  name     = "app-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.major.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    healthy_threshold   = 5
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    matcher             = "200-399"
  }
}

# Launch Template 

# Security group for the private EC2 instances (ASG)
resource "aws_security_group" "ec2_asg" {
  name        = "asg_ec2-security-group"
  description = "Allow HTTP from ALB only"
  vpc_id      = aws_vpc.major.id

  ingress {
    description                   = "Allow HTTP from ALB"
    from_port                   = var.private_ec2_port
    to_port                     = var.private_ec2_port
    protocol                    = "tcp"
    security_groups             = [aws_security_group.securi_group.id]
  }

   ingress {
    description                 = "Allow HTTPS from ALB"
    from_port                   = var.private_ec2_port_2
    to_port                     = var.private_ec2_port_2
    protocol                    = "tcp"
    security_groups             = [aws_security_group.securi_group.id]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ec2-security-group"
  }
}

resource "aws_launch_template" "ec2_template" {
  name_prefix   = "ec2_template"
  image_id      = "ami-08a6efd148b1f7504" 
  instance_type = "t2.micro"
  key_name      = var.key_name

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.ec2_asg.id]
  }

    user_data = base64encode(<<EOF
#!/bin/bash
yum update -y
yum install -y nginx

echo "<html><body><h1>Hello World</h1></body></html>" > /usr/share/nginx/html/index.html

systemctl enable nginx
systemctl start nginx
EOF
  )
}

# Auto Scaling Group with desired capacity and scaling policy
resource "aws_autoscaling_group" "main_asg" {
  name                      = "main-asg"
  max_size                  = 2
  min_size                  = 1
  desired_capacity          = 1
  vpc_zone_identifier       = [aws_subnet.private_subnet.id, aws_subnet.private_subnet_2.id]
  launch_template {
    id      = aws_launch_template.ec2_template.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.target_group.arn]

  tag {
    key                 = "production_ec2"
    value               = "list-of-asg-instance-for-production"
    propagate_at_launch = true
  }

  health_check_type         = "ELB"
  health_check_grace_period = 300
}
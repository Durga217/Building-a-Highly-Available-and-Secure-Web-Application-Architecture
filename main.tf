provider "aws" {
  region = "ap-south-1" # Replace with your desired region
}
# Auto Scaling Launch Template
resource "aws_launch_template" "web_server_lt" {
  name          = "web-server-launch-template"
  image_id      = "ami-053b12d3152c0cc71" 
  instance_type = "t2.micro"            
  network_interfaces {
    associate_public_ip_address = true
    subnet_id                   = "subnet-0e67a89dc05c9fad9" 
    security_groups             = [aws_security_group.web_server_sg.id]
  }
  user_data = base64encode(<<-EOT
              #!/bin/bash
              yum update -y
              yum install httpd -y
              systemctl start httpd
              systemctl enable httpd
              echo "Welcome to the Aara's Webpage" > /var/www/html/index.html
              EOT
  )
}
# Security Group for EC2 Instances
resource "aws_security_group" "web_server_sg" {
  name        = "web-server-sg"
  description = "Allow HTTP and SSH traffic"
  vpc_id      = "vpc-06b6ba41532501883" 
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
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
# Auto Scaling Group
resource "aws_autoscaling_group" "web_server_asg" {
  desired_capacity     = 2
  max_size             = 3
  min_size             = 1
  launch_template {
    id      = aws_launch_template.web_server_lt.id
    version = "$Latest"
  }
  vpc_zone_identifier  = ["subnet-0e67a89dc05c9fad9"] 
  health_check_type    = "EC2"
  health_check_grace_period = 300
  tag {
    key                 = "Name"
    value               = "web-server"
    propagate_at_launch = true
  }
}
# Application Load Balancer
resource "aws_lb" "web_server_alb" {
  name               = "web-server-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web_server_sg.id]
  subnets            = ["subnet-0e67a89dc05c9fad9"] 
}
# Target Group
resource "aws_lb_target_group" "web_server_tg" {
  name     = "web-server-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "vpc-06b6ba41532501883" 
}
# Listener for ALB
resource "aws_lb_listener" "web_server_listener" {
  load_balancer_arn = aws_lb.web_server_alb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_server_tg.arn
  }
}

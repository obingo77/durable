provider "aws" {
  profile = "default"
  region  = "us-east-1"

  default_tags {
    tags = {
      Environment = "Test"
      Service     = "Example"
    }
  }
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.default.id
}
data "aws_availability_zones" "available" {
  state = "available"
}

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

  owners = ["099720109477"]
}

resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
}

resource "aws_launch_template" "example" {
  name_prefix   = "template-aws-default-tags-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  // security_groups = [aws_security_group.instance_id]
}

resource "aws_autoscaling_group" "example" {
  availability_zones = data.aws_availability_zones.available.names
  desired_capacity   = 1
  max_size           = 1
  min_size           = 1

  target_group_arns = [aws_lb_target_group.asg.arn]
  health_check_type = "ELB"

  launch_template {
    id      = aws_launch_template.example.id
    version = "$Latest"
  }
  dynamic "tag" {
    for_each = data.aws_default_tags.current.tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}
data "aws_default_tags" "current" {}

resource "aws_security_group" "alb" {

  name = "lb-sg"

  ingress {
    description = " access to web app"
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

resource "aws_lb_target_group" "asg" {
  name                 = "lb-target-grp"
  port                 = 80
  protocol             = "HTTP"
  vpc_id               = data.aws_vpc.default.id
  deregistration_delay = 10


  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 10
    timeout             = 30
    interval            = 60
    protocol            = "HTTP"
  }

}


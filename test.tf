terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 2.70"
    }
  }
}
# Provider configuration

provider "aws" {
  profile = "default"
  region  = "eu-west-1"
}

#==========================#
# Networking configuration #
#==========================#

#  First we need a VPC for this project to live in 

resource "aws_vpc" "tims-vpc" {
 cidr_block = "10.0.1.0/24"
}

#  Then a Subnet needs to be created - in a 'real world' example - we'd have more than one subnet - to cover multiAZ

resource "aws_subnet" "tims-subnet" {
  vpc_id     = aws_vpc.tims-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "eu-west-1c"
}

#  My initial attempts couldn't see out - this was because we were missing an IGW, Route Table and Association between them (the pain of moving off 'default')

resource "aws_internet_gateway" "tims-igw" {
    vpc_id = aws_vpc.tims-vpc.id
}

resource "aws_route_table" "tims-aws-route-table" {
    vpc_id = aws_vpc.tims-vpc.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.tims-igw.id
    }
}

resource "aws_route_table_association" "tims-route-table-association" {
    subnet_id = aws_subnet.tims-subnet.id
    route_table_id = aws_route_table.tims-aws-route-table.id
}

#  As we're forced to use VPC by the ELB - it makes sense to make a nice restrictive NACL rule

resource "aws_network_acl" "tims-nacl" {
  vpc_id = aws_vpc.tims-vpc.id
}

resource "aws_network_acl_rule" "tims-nacl-rule" {
  network_acl_id = aws_network_acl.tims-nacl.id
  rule_number    = 200
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 22
  to_port        = 22
}

# NACLs are the like 'Router level' security rules - while SG's are service level firewalls - I created the rule seperate from the default.

resource "aws_security_group" "tims-sg-allow-ssh" {
  name        = "tims-sg-allow-ssh"
  description = "Allow SSH inbound traffic"
  vpc_id      = aws_vpc.tims-vpc.id

  ingress {
    description = "SSH for VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
    egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}

#  I'm used to Centos - so I picked that as a base image - I also have a predefined keypair - so I associated that too 

#==========================#
#    Auto scaling config   #
#==========================#
resource "aws_launch_configuration" "tims-launch-configuration" {
  name_prefix   = "tims-launch-configuration-"
  image_id      = "ami-0bfa4fefe067b7946"
  instance_type = "t2.micro"
  associate_public_ip_address = false
  key_name      = "incomprehensible-keypair"
  security_groups = [aws_security_group.tims-sg-allow-ssh.id]
  
  lifecycle {
    create_before_destroy = true
  }
}

#  I'm used to Centos - so I picked that as a base image - I also have a predefined keypair - so I associated that too 

resource "aws_autoscaling_group" "tims-autoscaling-group" {
  name                 = "tims-autoscaling-group"
  launch_configuration = aws_launch_configuration.tims-launch-configuration.name
  min_size             = 1
  max_size             = 1
  health_check_grace_period = 300
  health_check_type         = "ELB"
  desired_capacity          = 1
  force_delete              = true
  vpc_zone_identifier       = [aws_subnet.tims-subnet.id]
  load_balancers = [aws_elb.tims-elb.id]
  lifecycle {
    create_before_destroy = true
  }
}

#==========================#
#   ELB configuration      #
#==========================#

resource "aws_elb" "tims-elb" {
  name               		  = "tims-elb"
  subnets            		  = [aws_subnet.tims-subnet.id]
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400
  security_groups = [aws_security_group.tims-sg-allow-ssh.id]

  listener {
    instance_port     = 22
    instance_protocol = "tcp"
    lb_port           = 22
    lb_protocol       = "tcp"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 25
    target              = "TCP:22"
    interval            = 30
  }
}

#===========================#
#   Route 53 configuration	#
#===========================#

resource "aws_route53_record" "www" {
  zone_id = "Z326GWB4WZIEJJ"
  name    = "terraform.incomprehensible.co.uk"
  type    = "CNAME"
  ttl     = "300"
  records = [aws_elb.tims-elb.dns_name]
}
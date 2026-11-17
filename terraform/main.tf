terraform {
  required_version = ">= 1.8, < 2.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region              = var.aws_region
  allowed_account_ids = [var.aws_account_id]
  default_tags {
    tags = {
      Project   = "optima-devops-pz12"
      ManagedBy = "Terraform"
    }
  }
}

data "aws_subnet" "selected" {
  id = var.subnet_id
}

data "aws_ami" "ubuntu" {
  owners = ["099720109477"]
  filter {
    name   = "image-id"
    values = [var.ami_id]
  }
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}

resource "aws_security_group" "pz12" {
  name_prefix = "optima-pz12-"
  description = "Dedicated group for the Terraform deployment lab"
  vpc_id      = data.aws_subnet.selected.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  count             = var.ssh_cidr == null ? 0 : 1
  security_group_id = aws_security_group.pz12.id
  description       = "Temporary approved client IPv4 on TCP22"
  cidr_ipv4         = var.ssh_cidr
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
}

resource "aws_vpc_security_group_ingress_rule" "app" {
  count             = var.app_cidr == null ? 0 : 1
  security_group_id = aws_security_group.pz12.id
  description       = "Approved test client IPv4 on TCP3000"
  cidr_ipv4         = var.app_cidr
  ip_protocol       = "tcp"
  from_port         = 3000
  to_port           = 3000
}

resource "aws_vpc_security_group_egress_rule" "web" {
  for_each          = toset(["80", "443"])
  security_group_id = aws_security_group.pz12.id
  description       = "Ubuntu package mirrors and Docker Hub"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = tonumber(each.key)
  to_port           = tonumber(each.key)
}

resource "aws_instance" "pz12" {
  ami                                  = data.aws_ami.ubuntu.id
  instance_type                        = var.instance_type
  subnet_id                            = data.aws_subnet.selected.id
  associate_public_ip_address          = true
  key_name                             = var.key_name
  vpc_security_group_ids               = [aws_security_group.pz12.id]
  instance_initiated_shutdown_behavior = "stop"
  user_data                            = <<-CLOUD_INIT
    #cloud-boothook
    #!/bin/sh
    /sbin/shutdown -P +105 'Lab instance time limit'
  CLOUD_INIT

  credit_specification {
    cpu_credits = "standard"
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    encrypted             = true
    volume_type           = "gp3"
    volume_size           = 10
    delete_on_termination = true
  }

  tags = {
    Name = "optima-devops-pz12"
  }
}

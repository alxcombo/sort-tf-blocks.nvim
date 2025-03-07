# Terraform configuration

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.14.0"

  name = "my-vpc"
  cidr = "10.0.0.0/16"
}

# Database configuration
resource "aws_db_instance" "default" {
  allocated_storage    = 10
  engine              = "mysql"
  engine_version      = "5.7"
  instance_class      = "db.t3.micro"
  name                = "mydb"
  username            = var.db_username
  password            = var.db_password_secret_arn
  parameter_group_name = "default.mysql5.7"
  skip_final_snapshot = true
}

variable "region" {
  description = "AWS region"
  default     = "us-west-2"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  default     = "dev"
  type        = string
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

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"

  tags = {
    Name = "HelloWorld"
  }
}

output "instance_ip" {
  value = aws_instance.web.public_ip
}

# Network configuration
module "security_groups" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "4.9.0"

  name        = "web-sg"
  description = "Security group for web servers"
  vpc_id      = module.vpc.vpc_id
}

data "aws_availability_zones" "available" {
  state = "available"
}

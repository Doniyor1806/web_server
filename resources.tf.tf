resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = file("~/.ssh/id_ed25519.pub") #uzgartir/tekshir
}

variable "prefix" {
  type = string
  default = "project-aug-28" # uzgartir/tekshir
}

resource "aws_vpc" "main" {
  cidr_block = "172.16.0.0/16"
  tags       = {
    Name = join("-", ["${var.prefix}", "vpc"])
  }
}

resource "aws_subnet" "main" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "172.16.0.0/24" #tekshir/uzgartir

  tags = {
    Name = join("-", ["${var.prefix}", "subnet"])
  }
}

module "remote_module" {
  # source = terraform-aws-security-groups-027
  source  = "app.terraform.io/027-spring-cloud/security-groups-027/aws" #uzini remote modulini qoy
  version = "1.0.0"
  vpc_id  = aws_vpc.main.id

  security_groups = {
    "web" = {
      "description" = "Security Group for Web Tier"
      "ingress_rules" = [
        {
          to_port     = 22
          from_port   = 22
          cidr_blocks = ["0.0.0.0/0"]
          protocol    = "tcp"
          description = "ssh ingress rule"

        },
        {
          to_port     = 80
          from_port   = 80
          cidr_blocks = ["0.0.0.0/0"]
          protocol    = "tcp"
          description = "http ingress rule"
        },
        {
          to_port     = 443
          from_port   = 443
          cidr_blocks = ["0.0.0.0/0"]
          protocol    = "tcp"
          description = "https ingress rule"
        }
      ]
    },
  }
}

resource "aws_instance" "server" {
  ami           = "ami-066784287e358dad1"
  instance_type = "t2.micro"
  key_name      = aws_key_pair.deployer.key_name

  subnet_id              = aws_subnet.main.id
  vpc_security_group_ids = [module.remote_module.security_group_id["web"]]

  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo yum install -y httpd
              sudo systemctl start httpd.service
              sudo systemctl enable httpd.service
              sudo echo "<h1> Hello World from BamBam </h1>" > /var/www/html/index.html                   
              EOF 

  tags = {
    Name = join("-", [var.prefix, "ec2"])
  }
}
resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = file("~/.ssh/id_ed25519.pub") #checked
}
variable "prefix" {
  type    = string
  default = "project-aug-28-web-server" #changed
}

##############################################(added)
variable "instance_count" {
  type    = number
  default = 3
}

locals {
  instance_names = [for i in range(var.instance_count) : "${var.prefix}-ec2-${i + 1}"]
}

###############################################




resource "aws_vpc" "main" {
  cidr_block = "172.16.0.0/16"
  tags = {
    Name = join("-", [var.prefix, "vpc"])
  }
}
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}


resource "aws_subnet" "main_a" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "172.16.1.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = join("-", [var.prefix, "subnet"])
  }
}

resource "aws_subnet" "main_b" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "172.16.2.0/24"
  availability_zone = "us-east-1b"
  tags = {
    Name = join("-", [var.prefix, "subnet"])
  }
}


resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}
resource "aws_route_table_association" "main" {
  subnet_id      = aws_subnet.main_a.id
  route_table_id = aws_route_table.main.id
}
module "security-grp" {
  source  = "app.terraform.io/donis_cloud/security-grp/aws"
  version = "2.0.0"
  vpc_id  = aws_vpc.main.id
  security_groups = {
    "web" = {
      description = "Security Group for Web Tier"
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
      ],
      "egress_rules" = [
        {
          to_port     = 0
          from_port   = 0
          cidr_blocks = ["0.0.0.0/0"]
          protocol    = "-1" # This allows all outbound traffic
          description = "allow all outbound traffic"
        }
      ]
    }
  }
}

locals {
  web_servers = [
    "web-server-001", #"44.222.2.28"
    "web-server-002", #"3.216.63.186"
    "web-server-003"  #"44.214.243.175"
  ]
}


resource "aws_instance" "server" {
  for_each               = toset(local.web_servers)
  ami                    = "ami-0182f373e66f89c85"
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.deployer.key_name
  subnet_id              = aws_subnet.main_a.id
  vpc_security_group_ids = [module.security-grp.security_group_id["web"]]

  user_data = <<-EOF
                     #!/bin/bash
                     sudo yum update -y
                     sudo yum install -y httpd
                     sudo systemctl start httpd.service
                     sudo systemctl enable httpd.service
                     echo "<h1> Hello World from DS ${each.key} </h1>" | sudo tee /var/www/html/index.html
  EOF
  tags = {
    Name = join("-", [var.prefix, "ec2"])
  }
  lifecycle { ### this is for recreating resource and relaunching
    create_before_destroy = true
  }
}

resource "aws_eip" "instance_ip" {
  for_each = aws_instance.server
  instance = each.value.id
  domain   = "vpc"

}
# output "instance_public_ip" {
#   value = aws_eip.instance_ip.public_ip # Output the public IP of the Elastic IP #### i need it bcause it's for only 1 instance
# }

################################## (added)
output "instance_public_ips" {
  value = { for instance, value in aws_eip.instance_ip : instance => value.public_ip }
}

##################################


resource "aws_lb" "test" {
  name               = "test-lb-tf"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [module.security-grp.security_group_id.web]
  subnets            = [aws_subnet.main_a.id, aws_subnet.main_b.id] ###### 1

  enable_deletion_protection = false


  tags = {
    Environment = "production"
  }
}

resource "aws_lb_target_group" "test" {
  name     = "tf-example-lb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}


resource "aws_lb" "front_end" {
  name               = "front-end-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [module.security-grp.security_group_id.web]
  subnets            = [aws_subnet.main_a.id, aws_subnet.main_b.id]

  enable_deletion_protection = false

  tags = {
    Environment = "production"
  }
}


resource "aws_lb_target_group" "front_end" {
  name     = "front-end-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.front_end.arn
  port              = "443"
  protocol          = "HTTP"


  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.front_end.arn
  }
}

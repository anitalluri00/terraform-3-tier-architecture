terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

############################
# VPC
############################

resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "swiggy-VPC"
  }
}

############################
# SUBNETS
############################

resource "aws_subnet" "web_subnet_1" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = { Name = "swiggy-Web-subnet-1a" }
}

resource "aws_subnet" "web_subnet_2" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = { Name = "swiggy-Web-subnet-1b" }
}

resource "aws_subnet" "application_subnet_1" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = "us-east-1a"

  tags = { Name = "swiggy-App-subnet-1a" }
}

resource "aws_subnet" "application_subnet_2" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.12.0/24"
  availability_zone = "us-east-1b"

  tags = { Name = "swiggy-App-subnet-1b" }
}

resource "aws_subnet" "database_subnet_1" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.21.0/24"
  availability_zone = "us-east-1a"

  tags = { Name = "swiggy-DB-subnet-1a" }
}

resource "aws_subnet" "database_subnet_2" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.22.0/24"
  availability_zone = "us-east-1b"

  tags = { Name = "swiggy-DB-subnet-1b" }
}

############################
# INTERNET GATEWAY + ROUTE
############################

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.my_vpc.id
  tags = { Name = "SWIGGY-IGW" }
}

resource "aws_route_table" "web_rt" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = { Name = "WebRT" }
}

resource "aws_route_table_association" "web_a" {
  subnet_id      = aws_subnet.web_subnet_1.id
  route_table_id = aws_route_table.web_rt.id
}

resource "aws_route_table_association" "web_b" {
  subnet_id      = aws_subnet.web_subnet_2.id
  route_table_id = aws_route_table.web_rt.id
}

############################
# SECURITY GROUPS
############################

resource "aws_security_group" "webserver_sg" {
  name   = "webserver-sg"
  vpc_id = aws_vpc.my_vpc.id

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 80
    to_port   = 80
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "appserver_sg" {
  name   = "appserver-SG"
  vpc_id = aws_vpc.my_vpc.id

  ingress {
    from_port = 8080
    to_port   = 8080
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "database_sg" {
  name   = "Database-SG"
  vpc_id = aws_vpc.my_vpc.id

  ingress {
    from_port = 3306
    to_port   = 3306
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

############################
# EC2 INSTANCES
############################

resource "aws_instance" "webserver1" {
  ami           = "ami-0ddc798b3f1a5117e"
  instance_type = "t2.micro"
  key_name      = "All"
  subnet_id     = aws_subnet.web_subnet_1.id
  vpc_security_group_ids = [aws_security_group.webserver_sg.id]
  user_data = file("apache.sh")

  tags = { Name = "SWIGGY-Web-Server-1" }
}

resource "aws_instance" "webserver2" {
  ami           = "ami-0ddc798b3f1a5117e"
  instance_type = "t2.micro"
  key_name      = "All"
  subnet_id     = aws_subnet.web_subnet_2.id
  vpc_security_group_ids = [aws_security_group.webserver_sg.id]
  user_data = file("apache.sh")

  tags = { Name = "SWIGGY-Web-Server-2" }
}

resource "aws_instance" "appserver1" {
  ami           = "ami-0ddc798b3f1a5117e"
  instance_type = "t2.micro"
  key_name      = "All"
  subnet_id     = aws_subnet.application_subnet_1.id
  vpc_security_group_ids = [aws_security_group.appserver_sg.id]

  tags = { Name = "SWIGGY-app-Server-1" }
}

resource "aws_instance" "appserver2" {
  ami           = "ami-0ddc798b3f1a5117e"
  instance_type = "t2.micro"
  key_name      = "All"
  subnet_id     = aws_subnet.application_subnet_2.id
  vpc_security_group_ids = [aws_security_group.appserver_sg.id]

  tags = { Name = "SWIGGY-app-Server-2" }
}

############################
# RDS
############################

resource "aws_db_subnet_group" "default" {
  name       = "main"
  subnet_ids = [aws_subnet.database_subnet_1.id, aws_subnet.database_subnet_2.id]
}

resource "aws_db_instance" "default" {
  allocated_storage    = 10
  db_name              = "mydb"
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = "db.t3.micro"
  username             = "admin"
  password             = "Raham#444555"
  parameter_group_name = "default.mysql8.0"
  skip_final_snapshot  = true
  db_subnet_group_name = aws_db_subnet_group.default.id
  vpc_security_group_ids = [aws_security_group.database_sg.id]
}

############################
# LOAD BALANCER
############################

resource "aws_lb" "external_elb" {
  name               = "SWIGGY-LB"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.webserver_sg.id]
  subnets            = [aws_subnet.web_subnet_1.id, aws_subnet.web_subnet_2.id]
}

resource "aws_lb_target_group" "external_elb" {
  name     = "ALB-TG"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.my_vpc.id
}

resource "aws_lb_target_group_attachment" "tg1" {
  target_group_arn = aws_lb_target_group.external_elb.arn
  target_id        = aws_instance.webserver1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "tg2" {
  target_group_arn = aws_lb_target_group.external_elb.arn
  target_id        = aws_instance.webserver2.id
  port             = 80
}

resource "aws_lb_listener" "external_elb" {
  load_balancer_arn = aws_lb.external_elb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.external_elb.arn
  }
}

output "lb_dns_name" {
  value = aws_lb.external_elb.dns_name
}

############################
# S3 + IAM
############################

resource "aws_s3_bucket" "example" {
  bucket = "pipleinbucket0088bdhuwtrrrrf3t5hd8e8r"
}

resource "aws_s3_bucket_versioning" "versioning_example" {
  bucket = aws_s3_bucket.example.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_iam_group" "group" {
  name = "test-group"
}

resource "aws_iam_user" "user_one" {
  name = "test-user"
}

resource "aws_iam_user" "user_two" {
  name = "test-user-two"
}

resource "aws_iam_group_membership" "team" {
  name = "tf-testing-group-membership"
  users = [
    aws_iam_user.user_one.name,
    aws_iam_user.user_two.name,
  ]
  group = aws_iam_group.group.name
}

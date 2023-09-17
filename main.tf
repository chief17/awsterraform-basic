terraform {

  required_providers {

    aws = {

      source  = "hashicorp/aws"

      version = "~> 4.16"

    }

  }



  required_version = ">= 1.2.0"

}



provider "aws" {
  region     = "ap-south-1"
  access_key = "ACCESS KEY"
  secret_key = "SECRET KEY"
}


resource "aws_vpc" "test-env" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support = true
  tags = {
    Name = "test-env"
  }
}

resource "aws_subnet" "subnet-uno" {
  cidr_block = "${cidrsubnet(aws_vpc.test-env.cidr_block, 3, 1)}"
  vpc_id = "${aws_vpc.test-env.id}"
  availability_zone = "ap-south-1a"
}

resource "aws_subnet" "subnet-duo-private" {
  cidr_block = "${cidrsubnet(aws_vpc.test-env.cidr_block, 3, 2)}"
  vpc_id = "${aws_vpc.test-env.id}"
  availability_zone = "ap-south-1a"
}
resource "aws_security_group" "ingress-all-test" {
  name = "allow-all-sg" 
  vpc_id = "${aws_vpc.test-env.id}"
  ingress {
    cidr_blocks = [
      "0.0.0.0/0"
    ]
    from_port = 22
    to_port = 22
    protocol = "tcp"
    
  }// Terraform removes the default rule
  ingress {
    cidr_blocks = [
      "0.0.0.0/0"
    ]
    from_port = 80
    to_port = 80
    protocol = "tcp"
    
  }
  egress {
   from_port = 0
   to_port = 0
   protocol = "-1"
   cidr_blocks = ["0.0.0.0/0"]
 }
 }

resource "aws_security_group" "private-net" {
  name = "allow-all-private" 
  vpc_id = "${aws_vpc.test-env.id}"
  ingress {
    cidr_blocks = [
      "10.0.0.0/16"
    ]
    from_port = 0
    to_port = 0
    protocol = "-1"
    
  }// Terraform removes the default rule
  
  egress {
   from_port = 0
   to_port = 0
   protocol = "-1"
   cidr_blocks = ["10.0.0.0/16"]
 }
 }

 resource "aws_instance" "test-ec2-instance" {
  ami = "ami-0f5ee92e2d63afc18"
  instance_type = "t2.micro"
  user_data = <<EOF
#!/bin/bash
echo "Copying the SSH Key to the server"
echo -e "SSH KEY ubuntu@ubuntu" >> /home/ubuntu/.ssh/authorized_keys
EOF
 
  security_groups = ["${aws_security_group.ingress-all-test.id}"]
  tags = {
    Name = "test-ec2-instance"
  }
  subnet_id = "${aws_subnet.subnet-uno.id}"
}

resource "aws_instance" "test-ec2-instance-mongod" {
  ami = "ami-0f5ee92e2d63afc18"
  instance_type = "t2.micro"
  user_data = <<EOF
#!/bin/bash
echo "Copying the SSH Key to the server"
echo -e "SSH KEY ubuntu@ubuntu" >> /home/ubuntu/.ssh/authorized_keys
EOF
 
  security_groups = ["${aws_security_group.private-net.id}"]
  tags = {
    Name = "test-ec2-instance-mongod"
  }
  subnet_id = "${aws_subnet.subnet-duo-private.id}"
}

resource "aws_eip" "ip-test-env" {
  instance = "${aws_instance.test-ec2-instance.id}"
  vpc      = true
}

resource "aws_internet_gateway" "test-env-gw" {
  vpc_id = "${aws_vpc.test-env.id}"
  tags = {
    Name = "test-env-gw"
  }
}

resource "aws_route_table" "route-table-test-env" {
  vpc_id = "${aws_vpc.test-env.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.test-env-gw.id}"
  }
  tags = {
    Name = "test-env-route-table"
  }
}

resource "aws_route_table_association" "subnet-association" {
  subnet_id      = "${aws_subnet.subnet-uno.id}"
  route_table_id = "${aws_route_table.route-table-test-env.id}"
}

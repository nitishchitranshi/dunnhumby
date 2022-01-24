// We are using AWS as a provider

provider "aws" {
  profile = "default"
  region  = "us-east-1"
}

// This will create the dunnhumby-vpc with CIDR Range as "10.0.0.0/16"
resource "aws_vpc" "dunnhumby-vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "Some Custom VPC"
  }
}

// Assuming the Subnet is public subnet as the type was not mentioned in the document.
resource "aws_subnet" "dunnhumby-subnet" {
  vpc_id            = aws_vpc.dunnhumby-vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "1a"

  tags = {
    Name = "Some Public Subnet"
  }
}

// The public subnet will also require some internet gateway
resource "aws_internet_gateway" "dh_ig" {
  vpc_id = aws_vpc.dunnhumby-vpc.id

  tags = {
    Name = "Some Internet Gateway"
  }
}


resource "aws_security_group" "web_sg" {
  name   = "HTTP and SSH"
  vpc_id = aws_vpc.dunnhumby-vpc.id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}

// For association of internet gateway in route table entry
resource "aws_route_table" "public_rt_dh" {
  vpc_id = aws_vpc.dunnhumby-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.dh_ig.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.dh_ig.id
  }

  tags = {
    Name = "Public Route Table"
  }
}

//For associating the route table with the required subnet
resource "aws_route_table_association" "public_1_rt_a" {
  subnet_id      = aws_subnet.dunnhumby-subnet.id
  route_table_id = aws_route_table.public_rt_dh.id
}


//For creating EC2 instance as required
resource "aws_instance" "dh-datapipeline" {
  ami           = "ami-08e4e35cccc6189f4" //Ami ID for Amazon Linux 2 available on us-east-1 region
  instance_type = "t2.micro"
  key_name      = "MyKeyPair"

  subnet_id                   = aws_subnet.dunnhumby-subnet.id
  vpc_security_group_ids      = [aws_security_group.web_sg.id]
  associate_public_ip_address = true

  user_data = <<-EOF
  #!/bin/bash -ex
  sudo yum update
  sudo yum install docker
  sudo systemctl enable docker.service
  sudo systemctl start docker.service
  docker run -d tutum/hello-world -p 8080:8080
  EOF

  tags = {
    "Name" : "Dunhumbby-Test"
  }
}

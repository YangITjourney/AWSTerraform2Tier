provider "aws" {
    region = "us-east-1"
}


# create vpc - demo_vpc
resource "aws_vpc" "demo_vpc" {
  cidr_block = "10.0.0.0/16"
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc

#output "vpc_id_output" {
#    value = data.aws_vpcs.vpc_list.ids
#}

resource "aws_subnet" "public_subnet" {
  vpc_id     = aws_vpc.demo_vpc.id
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch =  true
  availability_zone = "us-east-1a"
  depends_on = [ aws_vpc.demo_vpc ]
  tags = {
    Name = "public_subnet"
  }
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table
resource "aws_route_table" "my_route_table" {
  vpc_id = aws_vpc.demo_vpc.id
  tags = {
    Name = "routing table for pulic subnet"
  }
}

# associate subnet with routing table
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association
resource "aws_route_table_association" "public_route_assicate" {
    subnet_id = aws_subnet.public_subnet.id
    route_table_id = aws_route_table.my_route_table.id
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway
resource "aws_internet_gateway" "demo_IGW" {
  vpc_id = aws_vpc.demo_vpc.id
  depends_on = [ aws_vpc.demo_vpc ]
  tags = {
    Name = "demo_IGW"
  }
}

resource "aws_route" "default_route" {
  route_table_id = aws_route_table.my_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.demo_IGW.id
}

# create private subnet
resource "aws_subnet" "private_subnet" {
  vpc_id     = aws_vpc.demo_vpc.id
  cidr_block = "10.0.2.0/24"
  map_public_ip_on_launch =  false
  availability_zone = "us-east-1b"
  depends_on = [ aws_vpc.demo_vpc ]
  tags = {
    Name = "private_subnet"
  }
}

# Create security group SSH port 22
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group
resource "aws_security_group" "sg" {
  name        = "sg"
  description = "Used for access to the public instances"
  vpc_id      = aws_vpc.demo_vpc.id
  #Inbound internet access
  #SSH
  ingress {
    description = "Allow SSH traffic"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  #Outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "Terraform-SecurityGroup"
  }
}

# key pair for ec2 instance under public subnet
#https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key
resource "tls_private_key" "key_for_pub_snet" {
    algorithm = "RSA"
}

#https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/key_pair
resource "aws_key_pair" "key_pair_pub_snet" {
    key_name = "key_pub_snet"
    public_key = tls_private_key.key_for_pub_snet.public_key_openssh
}

resource "local_file" "key_pub_snet" {
    content = tls_private_key.key_for_pub_snet.private_key_pem
    filename= "key_pub_snet.pem"
}

#  key pair for ec2 instance under private subnet
resource "tls_private_key" "key_for_pri_snet" {
    algorithm = "RSA"
}
resource "aws_key_pair" "key_pair_pri_snet" {
    key_name = "key_pri_snet"
    public_key = tls_private_key.key_for_pri_snet.public_key_openssh
}
resource "local_file" "key_pri_snet" {
    content = tls_private_key.key_for_pri_snet.private_key_pem
    filename= "key_pri_snet.pem"
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami
data "aws_ami" "amazon_linux_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }
}

# create an ec2 instance in public subnet
resource "aws_instance" "server_pub" {
  instance_type = "t2.micro"
  ami = data.aws_ami.amazon_linux_ami.id
  subnet_id = aws_subnet.public_subnet.id
  key_name = "key_pub_snet"
  security_groups = [aws_security_group.sg.id]
  tags = {
    Name = "PublicInstance"
  }
  depends_on = [ aws_key_pair.key_pair_pri_snet ]
}

# create an ec2 instance in private subnet
resource "aws_instance" "server_pri" {
  instance_type = "t2.micro"
  ami = data.aws_ami.amazon_linux_ami.id
  subnet_id = aws_subnet.private_subnet.id
  key_name = "key_pri_snet"
  security_groups = [aws_security_group.sg.id]
  tags = {
    Name = "PrivateInstance"
  }
}

provider "aws" {
    region = "us-east-1"
}

# create vpc - demo_vpc
resource "aws_vpc" "demo_vpc" {
  cidr_block = "10.0.0.0/16"
}

# create public subnet
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

# define routing table for public routing table
resource "aws_route_table" "my_route_table" {
  vpc_id = aws_vpc.demo_vpc.id
  tags = {
    Name = "routing table for pulic subnet"
  }
}

# associate subnet with routing table
resource "aws_route_table_association" "public_route_assicate" {
    subnet_id = aws_subnet.public_subnet.id
    route_table_id = aws_route_table.my_route_table.id
}

# Internet gateway for Internet
resource "aws_internet_gateway" "demo_IGW" {
  vpc_id = aws_vpc.demo_vpc.id
  depends_on = [ aws_vpc.demo_vpc ]
}

# Add default route in routing table and point ot Internet Gateway
resource "aws_route" "default_route" {
  route_table_id = aws_route_table.my_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.demo_IGW.id
}

#Create SG for allowing TCP/22
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

# key pair for instance in private subnet
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

#Create a server in public subnet
resource "aws_instance" "server_pub" {
  instance_type = "t2.micro"
  ami = data.aws_ami.amazon_linux_ami.id
  subnet_id = aws_subnet.public_subnet.id
  key_name = "key_pub_snet"
  security_groups = [aws_security_group.sg.id]
  tags = {
    Name = "PublicInstance"
  }
}


#Create a server in private subnet
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

# scp -i key_pub_snet.pem ./key_pri_snet.pem ec2-user@18.205.119.65:~

# Create Elastic IP 
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip
resource "aws_eip" "ngw_eip" {
  depends_on = [ aws_internet_gateway.demo_IGW ]  
}

# Create NAT Gateway in public subnet
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/nat_gateway
resource "aws_nat_gateway" "demo_NGW" {
  allocation_id = aws_eip.ngw_eip.id
  subnet_id = aws_subnet.public_subnet.id
  depends_on = [ aws_eip.ngw_eip ]
}

# Create Private Route Table and route to point default route to NAT gateway
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.demo_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.demo_NGW.id
  }
  tags = {
    Name = "Private_Route_Table"
  }
}

# Associate Private route table to Private subnet
resource "aws_route_table_association" "Private_route_table_assiciate" {
  subnet_id = aws_subnet.private_subnet.id
  route_table_id =  aws_route_table.private_route_table.id
}

# scp -i key_pub_snet.pem ./key_pri_snet.pem ec2-user@ipaddress:~

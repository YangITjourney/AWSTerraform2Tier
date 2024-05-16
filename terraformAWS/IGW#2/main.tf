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



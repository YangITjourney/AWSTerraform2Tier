provider "aws" {
    region = "us-east-1"
}


# create vpc - demo_vpc
resource "aws_vpc" "demo_vpc" {
  cidr_block = "10.0.0.0/16"
}

# fetch the vpc list from aws
data "aws_vpcs" "vpc_list" {
}
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc

#output "vpc_id_output" {
#    value = data.aws_vpcs.vpc_list.ids
#}

output "demo_vpc_id" {
    value = aws_vpc.demo_vpc.id
}

resource "aws_subnet" "demo_subnet" {
  vpc_id     = aws_vpc.demo_vpc.id
  cidr_block = "10.0.1.0/24"
}

output "demo_subnet_id" {
    value = aws_subnet.demo_subnet.id
}
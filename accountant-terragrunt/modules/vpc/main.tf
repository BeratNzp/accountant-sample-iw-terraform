locals {
  # project_prefix = get_terragrunt_input("project_prefix", "accountant")
  project_prefix = var.env_prefix
  vpc_cidr_block = var.vpc_cidr_block
}

# Create a VPC
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr_block
  enable_dns_hostnames = true
  tags = {
    Name = "${local.project_prefix}-vpc"
  }
}

# # Create an Internet Gateway
# resource "aws_internet_gateway" "main" {
#   vpc_id = aws_vpc.main.id
#   tags = {
#     Name = "${local.project_prefix}-igw"
#   }
#   depends_on = [ aws_vpc.main ]
# }

# # Change the name of default route table to private route table
# resource "aws_default_route_table" "private" {
#   default_route_table_id = aws_vpc.main.default_route_table_id

#   tags = {
#     Name = "${local.project_prefix}-private-rt"
#   }
#   depends_on = [ aws_vpc.main ]
# }

# # Create a public route table
# resource "aws_route_table" "public" {
#   vpc_id = aws_vpc.main.id
#   route {
#     cidr_block = "0.0.0.0/0"
#     gateway_id = aws_internet_gateway.main.id
#   }
#   tags = {
#     Name = "${local.project_prefix}-public-rt"
#   }
#   depends_on = [ aws_vpc.main, aws_internet_gateway.main ]
# }

# # Create 1 public subnet
# resource "aws_subnet" "first_public" {
#   vpc_id     = aws_vpc.main.id
#   cidr_block = var.first_public_subnet_cidr_block
#   availability_zone = var.first_public_subnet_az
#   tags = {
#       Name = "${local.project_prefix}-public-subnet-${var.first_public_subnet_az}"
#   }
#   depends_on = [ aws_vpc.main ]
# }
# resource "aws_route_table_association" "public" {
#   subnet_id      = aws_subnet.first_public.id
#   route_table_id = aws_route_table.public.id
#   depends_on = [ aws_subnet.first_public, aws_route_table.public, aws_vpc.main ]
# }

# # Create 1 private subnet
# resource "aws_subnet" "first_private" {
#   vpc_id     = aws_vpc.main.id
#   cidr_block = var.first_private_subnet_cidr_block
#   availability_zone = var.first_private_subnet_az
#   tags = {
#       Name = "${local.project_prefix}-private-subnet-${var.first_private_subnet_az}"
#   }
#   depends_on = [ aws_vpc.main ]
# }
# resource "aws_route_table_association" "private" {
#   subnet_id      = aws_subnet.first_private.id
#   route_table_id = aws_default_route_table.private.id
#   depends_on = [ aws_subnet.first_private, aws_default_route_table.private ]
# }

# # Create a security group for execute-api
# resource "aws_security_group" "execute-api" {
#   name        = "${local.project_prefix}-execute-api"
#   description = "Allow inbound HTTP and HTTPS traffic"
#   vpc_id      = aws_vpc.main.id

#   ingress {
#     description = "HTTP"
#     from_port   = 80
#     to_port     = 80
#     protocol    = "tcp"
#     cidr_blocks = [aws_vpc.main.cidr_block]
#   }

#   ingress {
#     description = "HTTPS"
#     from_port   = 443
#     to_port     = 443
#     protocol    = "tcp"
#     cidr_blocks = [aws_vpc.main.cidr_block]
#   }

#   depends_on = [ aws_vpc.main ]
# }

# # Create a vpc endpoint for execute-api
# resource "aws_vpc_endpoint" "execute-api" {
#   vpc_id            = aws_vpc.main.id
#   service_name      = "com.amazonaws.${var.aws_region}.execute-api"
#   vpc_endpoint_type = "Interface"

#   security_group_ids = [aws_security_group.execute-api.id]

#   private_dns_enabled = true
#   subnet_ids          = [
#     aws_subnet.first_private.id,
#     aws_subnet.first_public.id
#   ]
#   tags = {
#     Name = "${local.project_prefix}-execute-api"
#   }
#   depends_on = [ aws_vpc.main, aws_security_group.execute-api, aws_subnet.first_private, aws_subnet.first_public ]
# }
# output "vpc_endpoint_execute_api" {
#   value = aws_vpc_endpoint.execute-api.id
#   depends_on = [ aws_vpc_endpoint.execute-api ]
# }
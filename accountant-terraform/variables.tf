variable "aws_region" {
  type        = string
  description = "The AWS region to deploy to."
  default     = "us-east-1"
}

variable "project_prefix" {
  type        = string
  description = "The prefix to use for all resources in this example."
  default     = "accountant"
}

variable "stage" {
  type        = string
  description = "The stage to deploy to."
  default     = "v1"
}

variable "vpc_cidr_block" {
  type        = string
  description = "The cidr block for the vpc."
  default     = "10.0.0.0/24"
}

variable "first_private_subnet_az" {
  type        = string
  description = "The availability zone for the first private subnet."
  default     = "us-east-1b"
}
variable "first_private_subnet_cidr_block" {
  type        = string
  description = "The cidr block for the first private subnet."
  default     = "10.0.0.128/28"
}

variable "first_public_subnet_az" {
  type        = string
  description = "The availability zone for the first public subnet."
  default     = "us-east-1a"
}
variable "first_public_subnet_cidr_block" {
  type        = string
  description = "The cidr block for the first public subnet."
  default     = "10.0.0.0/28"
}
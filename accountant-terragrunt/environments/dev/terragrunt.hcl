include {
  path = find_in_parent_folders()
}

terraform {
  source = "${get_path_to_repo_root()}/modules/vpc"
}

locals {
  env_name = basename(get_terragrunt_dir())
  env_prefix = "${local.project_prefix}-${local.env_name}"
}

inputs = {
  region = "us-east-1"

  stage = basename(get_terragrunt_dir())

  vpc_cidr_block = "10.0.0.0/24"

  first_private_subnet_az = "us-east-1a"
  first_private_subnet_cidr_block = "10.0.0.128/28"

  first_public_subnet_az = "us-east-1a"
  first_public_subnet_cidr_block = "10.0.0.0/28"
}
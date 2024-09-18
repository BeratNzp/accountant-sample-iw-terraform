remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket         = "accountant-terraform-state"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = "us-east-1" # default
    encrypt        = true
    dynamodb_table = "${path_relative_to_include()}-terraform-state-lock"
  }
}

inputs = {
  project_prefix = "accountant"
}
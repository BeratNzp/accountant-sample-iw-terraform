terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.34.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Create a dynamodb table for invoices
resource "aws_dynamodb_table" "invoices" {
  name           = "${var.project_prefix}-invoices"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = {
    Name = "${var.project_prefix}-invoices"
  }
}

# Create an assume role policy for lambda functions
data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# Create an iam policy for AWSLambdaBasicExecution and attach it to lambda functions
resource "aws_iam_policy_attachment" "AWSLambdaBasicExecution" {
  name       = "${var.project_prefix}-AWSLambdaBasicExecution"
  roles      = [ aws_iam_role.list-invoices.name, aws_iam_role.generate-invoice.name, aws_iam_role.list-invoices-as-pdf.name ]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  depends_on = [ aws_iam_role.list-invoices, aws_iam_role.generate-invoice, aws_iam_role.list-invoices-as-pdf ]
}

# Create an iam role, policy for "list-invoices" lambda and attach them
resource "aws_iam_role" "list-invoices" {
  name = "${var.project_prefix}-list-invoices-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
  depends_on = [ data.aws_iam_policy_document.assume_role_policy ]
}
resource "aws_iam_policy" "list-invoices-dynammodb-policy" {
  name = "${var.project_prefix}-list-invoices-dynammodb-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "dynamodb:GetItem",
          "dynamodb:Scan"
        ]
        Effect   = "Allow"
        Resource = aws_dynamodb_table.invoices.arn
      }
    ]
  })
  depends_on = [ aws_dynamodb_table.invoices ]
}
resource "aws_iam_role_policy_attachment" "list-invoices" {
  role       = aws_iam_role.list-invoices.name
  policy_arn = aws_iam_policy.list-invoices-dynammodb-policy.arn
  depends_on = [ aws_iam_role.list-invoices, aws_iam_policy.list-invoices-dynammodb-policy ]
}

# Create an iam role, policy for "generate-invoices" lambda and attach them
resource "aws_iam_role" "generate-invoice" {
  name = "${var.project_prefix}-generate-invoice-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
  depends_on = [ data.aws_iam_policy_document.assume_role_policy ]
}
resource "aws_iam_policy" "generate-invoice-dynamodb-policy" {
  name = "${var.project_prefix}-generate-invoice-dynamodb-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "dynamodb:PutItem"
        ]
        Effect   = "Allow"
        Resource = aws_dynamodb_table.invoices.arn
      }
    ]
  })
  depends_on = [ aws_dynamodb_table.invoices ]
}
resource "aws_iam_role_policy_attachment" "generate-invoice" {
  role       = aws_iam_role.generate-invoice.name
  policy_arn = aws_iam_policy.generate-invoice-dynamodb-policy.arn
  depends_on = [ aws_iam_role.generate-invoice, aws_iam_policy.generate-invoice-dynamodb-policy ]
}
resource "aws_iam_policy" "generate-invoice-s3-policy" {
  name = "${var.project_prefix}-generate-invoice-s3-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:PutObject"
        ]
        Effect   = "Allow"
        Resource = [
            "${aws_s3_bucket.invoices.arn}",
            "${aws_s3_bucket.invoices.arn}/*"
          ]
      }
    ]
  })
  depends_on = [ aws_s3_bucket.invoices ]
}
resource "aws_iam_role_policy_attachment" "generate-invoice-s3" {
  role       = aws_iam_role.generate-invoice.name
  policy_arn = aws_iam_policy.generate-invoice-s3-policy.arn
  depends_on = [ aws_iam_role.generate-invoice, aws_iam_policy.generate-invoice-s3-policy ]
}

# Create an iam role, policy for "list-invoices-as-pdf" lambda and attach them
resource "aws_iam_role" "list-invoices-as-pdf" {
  name = "${var.project_prefix}-list-invoices-as-pdf-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
  depends_on = [ data.aws_iam_policy_document.assume_role_policy ]
}
resource "aws_iam_policy" "list-invoices-as-pdf" {
  name = "${var.project_prefix}-list-invoices-as-pdf"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:ListBucket",
          "s3:GetObject"
        ]
        Effect   = "Allow"
        Resource = [
            "${aws_s3_bucket.invoices.arn}",
            "${aws_s3_bucket.invoices.arn}/*"
          ]
      }
    ]
  })
  depends_on = [ aws_dynamodb_table.invoices ]
}
resource "aws_iam_role_policy_attachment" "list-invoices-as-pdf" {
  role       = aws_iam_role.list-invoices-as-pdf.name
  policy_arn = aws_iam_policy.list-invoices-as-pdf.arn
  depends_on = [ aws_iam_role.list-invoices-as-pdf, aws_iam_policy.list-invoices-as-pdf ]
}

# Create a S3 bucket for generated PDF invoices and set it for static website hosting
resource "aws_s3_bucket" "invoices" {
  bucket = "${var.project_prefix}-invoices"
}
resource "aws_s3_bucket_public_access_block" "invoices" {
  bucket = aws_s3_bucket.invoices.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
  depends_on = [ aws_s3_bucket.invoices ]
}
resource "aws_s3_bucket_policy" "invoices" {
  bucket = aws_s3_bucket.invoices.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject"
        ]
        Effect   = "Allow"
        Resource = "${aws_s3_bucket.invoices.arn}/*"
        Principal = {
          AWS = "*"
        }
      }
    ]
  })
  depends_on = [ aws_s3_bucket.invoices ]
}
resource "aws_s3_bucket_website_configuration" "invoices" {
  bucket = aws_s3_bucket.invoices.id
  index_document {
    suffix = "index.html"
  }
  error_document {
    key = "error.html"
  }
  depends_on = [ aws_s3_bucket.invoices ]
}

# Create a rest api for invoices for list-invoices-as-pdf
resource "aws_api_gateway_rest_api" "invoices" {
  name        = "${var.project_prefix}-invoices-rest-api"
  description = "Invoices REST API"
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

# Create a lambda function for "list-invoices-as-pdf.py"
resource "aws_lambda_function" "list-invoices-as-pdf" {
  filename      = "lambda_functions/list-invoices-as-pdf.zip"
  function_name = "${var.project_prefix}-list-invoices-as-pdf"
  role          = aws_iam_role.list-invoices-as-pdf.arn
  handler       = "list-invoices-as-pdf.lambda_handler"
  runtime       = "python3.12"
  source_code_hash = filebase64sha256("lambda_functions/list-invoices-as-pdf.zip")
  environment {
    variables = {
      INVOICES_BUCKET_NAME = aws_s3_bucket.invoices.id
    }
  }
  depends_on = [ aws_iam_role.list-invoices-as-pdf ]
}
resource "aws_lambda_permission" "list-invoices-as-pdf" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.list-invoices-as-pdf.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.invoices.execution_arn}/*/*"
  depends_on = [ aws_lambda_function.list-invoices-as-pdf, aws_api_gateway_rest_api.invoices ]
}

# Create a GET method for list-invoices-as-pdf lambda
resource "aws_api_gateway_method" "list-invoices-as-pdf" {
  rest_api_id   = aws_api_gateway_rest_api.invoices.id
  resource_id   = aws_api_gateway_rest_api.invoices.root_resource_id
  http_method   = "GET"
  authorization = "NONE"
  depends_on = [ aws_api_gateway_rest_api.invoices, aws_lambda_function.list-invoices-as-pdf ]
}
resource "aws_api_gateway_integration" "list-invoices-as-pdf" {
  rest_api_id = aws_api_gateway_rest_api.invoices.id
  resource_id = aws_api_gateway_rest_api.invoices.root_resource_id
  http_method = aws_api_gateway_method.list-invoices-as-pdf.http_method
  integration_http_method = "POST"
  type = "AWS_PROXY"
  uri = aws_lambda_function.list-invoices-as-pdf.invoke_arn
  depends_on = [ aws_api_gateway_method.list-invoices-as-pdf, aws_lambda_function.list-invoices-as-pdf ]
}
resource "aws_api_gateway_method_response" "list-invoices-as-pdf" {
  rest_api_id = aws_api_gateway_rest_api.invoices.id
  resource_id = aws_api_gateway_rest_api.invoices.root_resource_id
  http_method = aws_api_gateway_method.list-invoices-as-pdf.http_method
  status_code = "200"
  depends_on = [ aws_api_gateway_method.list-invoices-as-pdf ]
}
resource "aws_api_gateway_integration_response" "list-invoices-as-pdf" {
  rest_api_id = aws_api_gateway_rest_api.invoices.id
  resource_id = aws_api_gateway_rest_api.invoices.root_resource_id
  http_method = aws_api_gateway_method.list-invoices-as-pdf.http_method
  status_code = aws_api_gateway_method_response.list-invoices-as-pdf.status_code
  response_templates = {
    "application/json" = ""
  }
  depends_on = [ aws_api_gateway_method_response.list-invoices-as-pdf, aws_lambda_function.list-invoices-as-pdf ]
}

# Deploy the invoices rest api
resource "aws_api_gateway_deployment" "invoices" {
  rest_api_id = aws_api_gateway_rest_api.invoices.id
  stage_name  = var.stage
  depends_on = [ 
    aws_api_gateway_rest_api.invoices,
    
    aws_api_gateway_method.list-invoices-as-pdf,
    aws_api_gateway_integration.list-invoices-as-pdf,
    aws_api_gateway_method_response.list-invoices-as-pdf,
    aws_api_gateway_integration_response.list-invoices-as-pdf
  ]
}

output "invoices_rest_api_url" {
  value = aws_api_gateway_deployment.invoices.invoke_url
  depends_on = [ aws_api_gateway_deployment.invoices ]
}

output "invoices_frontend_url" {
  value = "http://${aws_s3_bucket.invoices.id}.s3-website-${var.aws_region}.amazonaws.com"
  depends_on = [ aws_s3_bucket.invoices ]
}

# ### SEPERATE DASHBOARD ###

# Create a rest api for dashboard for list-invoices and generate-invoice
resource "aws_api_gateway_rest_api" "dashboard" {
  name        = "${var.project_prefix}-dashboard-rest-api"
  description = "Dashboard REST API"
  endpoint_configuration {
    types = ["PRIVATE"]
    vpc_endpoint_ids = [aws_vpc_endpoint.execute-api.id]
  }
  depends_on = [ aws_vpc_endpoint.execute-api ]
}

# Set policy for dashboard private rest api
resource "aws_api_gateway_rest_api_policy" "dashboard" {
  rest_api_id = aws_api_gateway_rest_api.dashboard.id
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "execute-api:Invoke"
        ]
        Effect   = "Allow"
        Resource = [
          "${aws_api_gateway_rest_api.dashboard.execution_arn}/*/*"
        ]
        Principal = "*"
      }
    ]
  })
  depends_on = [ aws_api_gateway_rest_api.dashboard, aws_vpc_endpoint.execute-api ]
}

# Create a lambda function for "list-invoices.py"
resource "aws_lambda_function" "list-invoices" {
  filename      = "lambda_functions/list-invoices.zip"
  function_name = "${var.project_prefix}-list-invoices"
  role          = aws_iam_role.list-invoices.arn
  handler       = "list-invoices.lambda_handler"
  runtime       = "python3.12"
  source_code_hash = filebase64sha256("lambda_functions/list-invoices.zip")
  environment {
    variables = {
      INVOICES_DYNAMODB_TABLE_NAME = aws_dynamodb_table.invoices.name
    }
  }
  depends_on = [ aws_iam_role.list-invoices ]
}
resource "aws_lambda_permission" "list-invoices" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.list-invoices.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.dashboard.execution_arn}/*/*"
  depends_on = [ aws_lambda_function.list-invoices, aws_api_gateway_rest_api.dashboard ]
}

# Create a GET method for list-invoices lambda
resource "aws_api_gateway_method" "list-invoices" {
  rest_api_id   = aws_api_gateway_rest_api.dashboard.id
  resource_id   = aws_api_gateway_rest_api.dashboard.root_resource_id
  http_method   = "GET"
  authorization = "NONE"
  depends_on = [ aws_api_gateway_rest_api.dashboard, aws_lambda_function.list-invoices ]
}
resource "aws_api_gateway_integration" "list-invoices" {
  rest_api_id = aws_api_gateway_rest_api.dashboard.id
  resource_id = aws_api_gateway_rest_api.dashboard.root_resource_id
  http_method = aws_api_gateway_method.list-invoices.http_method
  integration_http_method = "POST"
  type = "AWS_PROXY"
  uri = aws_lambda_function.list-invoices.invoke_arn
  depends_on = [ aws_api_gateway_method.list-invoices, aws_lambda_function.list-invoices ]
}
resource "aws_api_gateway_method_response" "list-invoices" {
  rest_api_id = aws_api_gateway_rest_api.dashboard.id
  resource_id = aws_api_gateway_rest_api.dashboard.root_resource_id
  http_method = aws_api_gateway_method.list-invoices.http_method
  status_code = "200"
  depends_on = [ aws_api_gateway_method.list-invoices ]
}
resource "aws_api_gateway_integration_response" "list-invoices" {
  rest_api_id = aws_api_gateway_rest_api.dashboard.id
  resource_id = aws_api_gateway_rest_api.dashboard.root_resource_id
  http_method = aws_api_gateway_method.list-invoices.http_method
  status_code = aws_api_gateway_method_response.list-invoices.status_code
  response_templates = {
    "application/json" = ""
  }
  depends_on = [ aws_api_gateway_method_response.list-invoices, aws_lambda_function.list-invoices ]
}

# Create a lambda function for "generate-invoice.py"
resource "aws_lambda_function" "generate-invoice" {
  filename      = "lambda_functions/generate-invoice.zip"
  function_name = "${var.project_prefix}-generate-invoice"
  role          = aws_iam_role.generate-invoice.arn
  handler       = "generate-invoice.lambda_handler"
  runtime       = "python3.12"
  source_code_hash = filebase64sha256("lambda_functions/generate-invoice.zip")
  environment {
    variables = {
      INVOICES_DYNAMODB_TABLE_NAME = aws_dynamodb_table.invoices.name,
      INVOICES_BUCKET_NAME = aws_s3_bucket.invoices.id
    }
  }
  depends_on = [ aws_iam_role.generate-invoice ]
}
resource "aws_lambda_permission" "generate-invoice" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.generate-invoice.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.dashboard.execution_arn}/*/*"
  depends_on = [ aws_lambda_function.generate-invoice, aws_api_gateway_rest_api.dashboard ]
}

# Create a POST method for generate-invoice lambda
resource "aws_api_gateway_method" "generate-invoice" {
  rest_api_id   = aws_api_gateway_rest_api.dashboard.id
  resource_id   = aws_api_gateway_rest_api.dashboard.root_resource_id
  http_method   = "POST"
  authorization = "NONE"
  depends_on = [ aws_api_gateway_rest_api.dashboard, aws_lambda_function.generate-invoice ]
}
resource "aws_api_gateway_integration" "generate-invoice" {
  rest_api_id = aws_api_gateway_rest_api.dashboard.id
  resource_id = aws_api_gateway_rest_api.dashboard.root_resource_id
  http_method = aws_api_gateway_method.generate-invoice.http_method
  integration_http_method = "POST"
  type = "AWS_PROXY"
  uri = aws_lambda_function.generate-invoice.invoke_arn
  depends_on = [ aws_api_gateway_method.generate-invoice, aws_lambda_function.generate-invoice ]
}
resource "aws_api_gateway_method_response" "generate-invoice" {
  rest_api_id = aws_api_gateway_rest_api.dashboard.id
  resource_id = aws_api_gateway_rest_api.dashboard.root_resource_id
  http_method = aws_api_gateway_method.generate-invoice.http_method
  status_code = "200"
  response_models = {
    "application/json" = "Empty"
  }
  depends_on = [ aws_api_gateway_method.generate-invoice ]
}
resource "aws_api_gateway_integration_response" "generate-invoice" {
  rest_api_id = aws_api_gateway_rest_api.dashboard.id
  resource_id = aws_api_gateway_rest_api.dashboard.root_resource_id
  http_method = aws_api_gateway_method.generate-invoice.http_method
  status_code = aws_api_gateway_method_response.generate-invoice.status_code
  response_templates = {
    "application/json" = ""
  }
  depends_on = [ aws_api_gateway_method_response.generate-invoice, aws_lambda_function.generate-invoice ]
}

# Deploy the dashboard rest api
resource "aws_api_gateway_deployment" "dashboard" {
  rest_api_id = aws_api_gateway_rest_api.dashboard.id
  stage_name  = var.stage
  depends_on = [ 
    aws_api_gateway_rest_api.dashboard,

    aws_api_gateway_method.list-invoices,
    aws_api_gateway_integration.list-invoices,
    aws_api_gateway_method_response.list-invoices,
    aws_api_gateway_integration_response.list-invoices,

    aws_api_gateway_method.generate-invoice,
    aws_api_gateway_integration.generate-invoice,
    aws_api_gateway_method_response.generate-invoice,
    aws_api_gateway_integration_response.generate-invoice
  ]
}

output "dashboard_rest_api_url" {
  value = aws_api_gateway_deployment.dashboard.invoke_url
  depends_on = [ aws_api_gateway_deployment.dashboard ]
}

# ### SEPERATE INVOICES ###
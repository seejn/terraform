# LocalStack Example - S3 and Lambda (SageMaker has limited support)
# This demonstrates Terraform with LocalStack for services that work well

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Variable to switch between LocalStack and real AWS
variable "use_localstack" {
  description = "Set to true to use LocalStack, false for real AWS"
  type        = bool
  default     = true
}

# LocalStack endpoint
locals {
  localstack_endpoint = "http://localhost:4566"
}

# Provider configuration
provider "aws" {
  region = "us-east-1"

  # Use fake credentials for LocalStack
  access_key = var.use_localstack ? "test" : null
  secret_key = var.use_localstack ? "test" : null

  # Skip AWS checks for LocalStack
  skip_credentials_validation = var.use_localstack
  skip_metadata_api_check     = var.use_localstack
  skip_requesting_account_id  = var.use_localstack

  # Configure endpoints for LocalStack
  endpoints {
    s3     = var.use_localstack ? local.localstack_endpoint : null
    iam    = var.use_localstack ? local.localstack_endpoint : null
    lambda = var.use_localstack ? local.localstack_endpoint : null
  }
}

# S3 Bucket (works great in LocalStack)
resource "aws_s3_bucket" "ml_data" {
  bucket = "ml-training-data-${random_id.suffix.hex}"

  tags = {
    Name        = "ML Training Data"
    Environment = var.use_localstack ? "localstack" : "aws"
  }
}

resource "random_id" "suffix" {
  byte_length = 4
}

# Upload sample data to S3
resource "aws_s3_object" "sample_data" {
  bucket  = aws_s3_bucket.ml_data.id
  key     = "data/sample.csv"
  content = <<-CSV
    name,age,score
    Alice,25,92.5
    Bob,30,88.0
    Charlie,35,95.5
  CSV

  content_type = "text/csv"
}

# IAM Role for Lambda (works in LocalStack)
resource "aws_iam_role" "lambda_role" {
  name = "localstack-lambda-role-${random_id.suffix.hex}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# Lambda function (works in LocalStack)
resource "aws_lambda_function" "data_processor" {
  filename         = "lambda_function.zip"
  function_name    = "localstack-data-processor"
  role            = aws_iam_role.lambda_role.arn
  handler         = "index.handler"
  runtime         = "python3.11"
  source_code_hash = filebase64sha256("lambda_function.zip")

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.ml_data.bucket
      ENVIRONMENT = var.use_localstack ? "localstack" : "aws"
    }
  }

  tags = {
    Name = "Data Processor Lambda"
  }
}

# Outputs
output "environment" {
  description = "Which environment is being used"
  value       = var.use_localstack ? "LocalStack (local)" : "AWS (real)"
}

output "bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.ml_data.bucket
}

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.data_processor.function_name
}

output "test_commands" {
  description = "Commands to test the deployment"
  value = var.use_localstack ? <<-EOT
    LocalStack Testing Commands:

    # List S3 buckets
    awslocal s3 ls

    # List files in bucket
    awslocal s3 ls s3://${aws_s3_bucket.ml_data.bucket}/

    # Download sample data
    awslocal s3 cp s3://${aws_s3_bucket.ml_data.bucket}/data/sample.csv -

    # List Lambda functions
    awslocal lambda list-functions

    # Invoke Lambda
    awslocal lambda invoke --function-name ${aws_lambda_function.data_processor.function_name} output.json
  EOT
  : <<-EOT
    AWS Testing Commands:

    # List S3 buckets
    aws s3 ls

    # List files in bucket
    aws s3 ls s3://${aws_s3_bucket.ml_data.bucket}/

    # Download sample data
    aws s3 cp s3://${aws_s3_bucket.ml_data.bucket}/data/sample.csv -

    # List Lambda functions
    aws lambda list-functions

    # Invoke Lambda
    aws lambda invoke --function-name ${aws_lambda_function.data_processor.function_name} output.json
  EOT
}

# NOTE: SageMaker support in LocalStack is limited
# For SageMaker development, use real AWS with small instance types:
# - ml.t3.medium for notebooks
# - ml.m5.large for training
# Remember to stop instances when not in use!

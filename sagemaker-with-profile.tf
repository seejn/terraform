# SageMaker with Custom AWS Profile

# Variables for flexibility
variable "aws_profile" {
  description = "AWS profile to use for authentication"
  type        = string
  default     = "default"  # Change this to your profile name
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

# Provider configuration with profile
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile  # ← This tells Terraform which profile to use
}

# Random suffix for unique names
resource "random_id" "suffix" {
  byte_length = 4
}

# S3 Bucket for SageMaker data
resource "aws_s3_bucket" "sagemaker_data" {
  bucket = "sagemaker-notebook-data-${random_id.suffix.hex}"

  tags = {
    Name        = "SageMaker Data Bucket"
    Profile     = var.aws_profile
    ManagedBy   = "Terraform"
  }
}

# IAM Role for SageMaker
resource "aws_iam_role" "sagemaker_notebook" {
  name = "sagemaker-notebook-role-${random_id.suffix.hex}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "sagemaker.amazonaws.com"
      }
    }]
  })
}

# Attach SageMaker policy
resource "aws_iam_role_policy_attachment" "sagemaker_full_access" {
  role       = aws_iam_role.sagemaker_notebook.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess"
}

# S3 access policy
resource "aws_iam_role_policy" "sagemaker_s3_access" {
  name = "sagemaker-s3-access"
  role = aws_iam_role.sagemaker_notebook.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:*"
      ]
      Resource = [
        aws_s3_bucket.sagemaker_data.arn,
        "${aws_s3_bucket.sagemaker_data.arn}/*"
      ]
    }]
  })
}

# SageMaker Notebook Instance
resource "aws_sagemaker_notebook_instance" "ml_notebook" {
  name                    = "ml-notebook-${random_id.suffix.hex}"
  instance_type           = "ml.t3.medium"
  role_arn                = aws_iam_role.sagemaker_notebook.arn
  volume_size             = 10
  direct_internet_access  = "Enabled"

  tags = {
    Name        = "ML Notebook"
    Environment = "development"
    Profile     = var.aws_profile
    ManagedBy   = "Terraform"
  }
}

# Outputs
output "profile_used" {
  description = "AWS profile used for this deployment"
  value       = var.aws_profile
}

output "region_used" {
  description = "AWS region used"
  value       = var.aws_region
}

output "notebook_name" {
  description = "Name of the SageMaker notebook"
  value       = aws_sagemaker_notebook_instance.ml_notebook.name
}

output "data_bucket_name" {
  description = "S3 bucket for your data"
  value       = aws_s3_bucket.sagemaker_data.bucket
}

output "notebook_url" {
  description = "URL to access notebook in AWS Console"
  value       = "https://console.aws.amazon.com/sagemaker/home?region=${var.aws_region}#/notebook-instances/${aws_sagemaker_notebook_instance.ml_notebook.name}"
}

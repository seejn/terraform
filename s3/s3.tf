variable "aws_profile" {
  description = "AWS profile to use for authentication"
  type        = string
  default     = "seejn"  # Change this to your profile name
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

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

resource "aws_s3_bucket" "testing_data" {
  bucket = "testing-${random_id.suffix.hex}"

  tags = {
    Name        = "testing"
    Purpose     = "testing"
    ManagedBy   = "Terraform"
  }
}

resource "random_id" "suffix" {
  byte_length = 4
}


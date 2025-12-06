# SageMaker Quick Start - Notebook Instance
# This creates a SageMaker notebook ready to use

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-south-1"
}

# S3 Bucket for SageMaker data and models
resource "aws_s3_bucket" "sagemaker_data" {
  bucket = "sagemaker-notebook-data-${random_id.suffix.hex}"

  tags = {
    Name        = "SageMaker Data Bucket"
    Purpose     = "ML experiments"
    ManagedBy   = "Terraform"
  }
}

resource "random_id" "suffix" {
  byte_length = 4
}

# IAM Role for SageMaker
resource "aws_iam_role" "sagemaker_notebook" {
  name = "sagemaker-notebook-role"

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

  tags = {
    Name = "SageMaker Notebook Role"
  }
}

# Attach AWS managed policy for SageMaker
resource "aws_iam_role_policy_attachment" "sagemaker_full_access" {
  role       = aws_iam_role.sagemaker_notebook.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess"
}

# S3 access policy for the data bucket
resource "aws_iam_role_policy" "sagemaker_s3_access" {
  name = "sagemaker-s3-access"
  role = aws_iam_role.sagemaker_notebook.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:*"
        ]
        Resource = [
          aws_s3_bucket.sagemaker_data.arn,
          "${aws_s3_bucket.sagemaker_data.arn}/*"
        ]
      }
    ]
  })
}

# Lifecycle Configuration - installs common ML packages
resource "aws_sagemaker_notebook_instance_lifecycle_configuration" "ml_setup" {
  name = "ml-package-installer"

  on_start = base64encode(<<-EOF
    #!/bin/bash
    set -e

    echo "Starting notebook instance setup..."

    # Install packages in the Python 3 environment
    sudo -u ec2-user -i <<'USEREOF'

    # Activate conda environment
    source /home/ec2-user/anaconda3/bin/activate python3

    # Install/upgrade common ML packages
    pip install --upgrade pip
    pip install --upgrade pandas numpy scikit-learn matplotlib seaborn
    pip install --upgrade boto3

    echo "Package installation complete!"

    conda deactivate
    USEREOF

    echo "Setup finished successfully"
    EOF
  )
}

# SageMaker Notebook Instance
resource "aws_sagemaker_notebook_instance" "ml_notebook" {
  name                    = "ml-notebook-quickstart"
  instance_type           = "ml.t3.medium"  # Free tier eligible
  role_arn                = aws_iam_role.sagemaker_notebook.arn
  lifecycle_config_name   = aws_sagemaker_notebook_instance_lifecycle_configuration.ml_setup.name
  volume_size             = 10  # GB
  direct_internet_access  = "Enabled"

  tags = {
    Name        = "ML Notebook"
    Environment = "development"
    ManagedBy   = "Terraform"
  }
}

# Outputs - Important information
output "notebook_name" {
  description = "Name of the SageMaker notebook"
  value       = aws_sagemaker_notebook_instance.ml_notebook.name
}

output "notebook_url" {
  description = "URL to access the notebook (will be available after notebook starts)"
  value       = "https://${aws_sagemaker_notebook_instance.ml_notebook.name}.notebook.us-east-1.sagemaker.aws"
}

output "data_bucket_name" {
  description = "S3 bucket for your data and models"
  value       = aws_s3_bucket.sagemaker_data.bucket
}

output "aws_console_url" {
  description = "Direct link to SageMaker in AWS Console"
  value       = "https://console.aws.amazon.com/sagemaker/home?region=us-east-1#/notebook-instances/${aws_sagemaker_notebook_instance.ml_notebook.name}"
}

output "next_steps" {
  description = "What to do next"
  value = <<-EOT

  ✓ Notebook created successfully!

  Next steps:
  1. Wait 2-3 minutes for notebook to start
  2. Check status: aws sagemaker describe-notebook-instance --notebook-instance-name ${aws_sagemaker_notebook_instance.ml_notebook.name}
  3. Open Jupyter: Click 'Open JupyterLab' in AWS Console
  4. Your S3 bucket: ${aws_s3_bucket.sagemaker_data.bucket}

  Or use the AWS Console link above to access your notebook directly.
  EOT
}

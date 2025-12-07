# Terraform Hands-On Labs

Complete these labs in order to build your skills progressively.

## Table of Contents
1. [Lab 1: First Steps (30 min)](#lab-1-first-steps)
2. [Lab 2: Deploy EC2 with VPC (45 min)](#lab-2-deploy-ec2-with-vpc)
3. [Lab 3: Lambda with S3 Trigger (45 min)](#lab-3-lambda-with-s3-trigger)
4. [Lab 4: Complete SageMaker Environment (60 min)](#lab-4-complete-sagemaker-environment)
5. [Lab 5: Full Application Stack (90 min)](#lab-5-full-application-stack)

---

## Lab 1: First Steps

**Goal:** Create your first resource with Terraform.

**Time:** 30 minutes

### Prerequisites
```bash
# Install Terraform
sudo snap install terraform --classic

# Verify installation
terraform version

# Configure AWS
aws configure
```

### Step 1: Create S3 Bucket

```bash
# Create directory
mkdir -p ~/terraform-labs/lab1
cd ~/terraform-labs/lab1

# Create configuration
cat > main.tf << 'EOF'
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# Random suffix for unique bucket name
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# S3 Bucket
resource "aws_s3_bucket" "lab1" {
  bucket = "terraform-lab1-${random_id.bucket_suffix.hex}"

  tags = {
    Name        = "Lab 1 Bucket"
    Environment = "learning"
    Lab         = "1"
  }
}

# Enable versioning
resource "aws_s3_bucket_versioning" "lab1" {
  bucket = aws_s3_bucket.lab1.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Output bucket name
output "bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.lab1.bucket
}

output "bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.lab1.arn
}
EOF
```

### Step 2: Initialize and Apply

```bash
# Initialize Terraform
terraform init

# Expected output:
# - Downloads AWS provider
# - Creates .terraform directory

# Format code
terraform fmt

# Validate syntax
terraform validate

# Preview changes
terraform plan

# Expected output:
# - Will create 3 resources
# - Shows resource details

# Apply changes
terraform apply

# Type 'yes' when prompted
```

### Step 3: Verify

```bash
# View outputs
terraform output

# Check bucket in AWS
aws s3 ls | grep terraform-lab1

# Upload a test file
echo "Hello Terraform!" > test.txt
aws s3 cp test.txt s3://$(terraform output -raw bucket_name)/

# Verify upload
aws s3 ls s3://$(terraform output -raw bucket_name)/
```

### Step 4: Modify and Update

```bash
# Add encryption to main.tf
cat >> main.tf << 'EOF'

# Enable encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "lab1" {
  bucket = aws_s3_bucket.lab1.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
EOF

# Plan the change
terraform plan

# Apply the change
terraform apply
```

### Step 5: Destroy

```bash
# Destroy all resources
terraform destroy

# Type 'yes' when prompted

# Verify deletion
aws s3 ls | grep terraform-lab1
# Should return nothing
```

### Lab 1 Quiz

Answer these questions:
1. What does `terraform init` do?
2. What's the difference between `plan` and `apply`?
3. Why do we need `random_id` for the bucket name?
4. What happens to the state file after `destroy`?

---

## Lab 2: Deploy EC2 with VPC

**Goal:** Create a complete network with EC2 instance.

**Time:** 45 minutes

### Step 1: Setup

```bash
mkdir -p ~/terraform-labs/lab2
cd ~/terraform-labs/lab2
```

### Step 2: Create VPC Configuration

```bash
cat > vpc.tf << 'EOF'
# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "lab2-vpc"
    Lab  = "2"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "lab2-igw"
  }
}

# Public Subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "lab2-public-subnet"
  }
}

# Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "lab2-public-rt"
  }
}

# Route Table Association
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}
EOF
```

### Step 3: Create EC2 Configuration

```bash
cat > ec2.tf << 'EOF'
# Data source for latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Security Group
resource "aws_security_group" "web" {
  name        = "lab2-web-sg"
  description = "Allow HTTP and SSH"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from anywhere (for lab only!)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "lab2-web-sg"
  }
}

# EC2 Instance
resource "aws_instance" "web" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web.id]

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd

              # Create a simple webpage
              cat > /var/www/html/index.html << 'HTML'
              <!DOCTYPE html>
              <html>
              <head>
                  <title>Terraform Lab 2</title>
                  <style>
                      body { font-family: Arial; text-align: center; padding: 50px; }
                      h1 { color: #232F3E; }
                      .info { background: #f0f0f0; padding: 20px; margin: 20px auto; max-width: 600px; }
                  </style>
              </head>
              <body>
                  <h1>Hello from Terraform!</h1>
                  <div class="info">
                      <h2>Instance Details</h2>
                      <p><strong>Hostname:</strong> $(hostname)</p>
                      <p><strong>IP:</strong> $(hostname -I)</p>
                      <p><strong>Lab:</strong> 2</p>
                  </div>
              </body>
              </html>
HTML
              EOF

  tags = {
    Name = "lab2-web-server"
    Lab  = "2"
  }
}
EOF
```

### Step 4: Create Outputs

```bash
cat > outputs.tf << 'EOF'
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.web.id
}

output "instance_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_instance.web.public_ip
}

output "web_url" {
  description = "URL to access the web server"
  value       = "http://${aws_instance.web.public_ip}"
}
EOF
```

### Step 5: Create Provider Configuration

```bash
cat > provider.tf << 'EOF'
terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}
EOF
```

### Step 6: Deploy

```bash
# Initialize
terraform init

# Plan
terraform plan

# Count how many resources will be created
terraform plan | grep "# aws"

# Apply
terraform apply -auto-approve

# Wait 2-3 minutes for user_data to complete
sleep 180

# Test the web server
curl $(terraform output -raw web_url)

# Or open in browser
xdg-open $(terraform output -raw web_url)
```

### Step 7: Experiments

Try these modifications:

**Experiment 1: Change instance type**
```bash
# Edit ec2.tf, change instance_type to "t2.small"
nano ec2.tf

# See what will change
terraform plan

# Apply
terraform apply
```

**Experiment 2: Add another security group rule**
```bash
# Add to ec2.tf in aws_security_group "web" block
cat >> ec2.tf << 'EOF'

  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
EOF

terraform apply
```

### Step 8: Cleanup

```bash
terraform destroy -auto-approve
```

---

## Lab 3: Lambda with S3 Trigger

**Goal:** Create a Lambda function triggered by S3 uploads.

**Time:** 45 minutes

### Step 1: Setup

```bash
mkdir -p ~/terraform-labs/lab3
cd ~/terraform-labs/lab3
mkdir lambda
```

### Step 2: Create Lambda Function Code

```bash
cat > lambda/index.py << 'EOF'
import json
import boto3
import os

s3 = boto3.client('s3')

def handler(event, context):
    print("Lambda triggered!")
    print("Event:", json.dumps(event))

    # Process each S3 record
    for record in event['Records']:
        bucket = record['s3']['bucket']['name']
        key = record['s3']['object']['key']

        print(f"Processing: s3://{bucket}/{key}")

        # Get object metadata
        response = s3.head_object(Bucket=bucket, Key=key)
        size = response['ContentLength']

        print(f"File size: {size} bytes")

        # Create metadata file
        metadata = {
            'original_file': key,
            'size_bytes': size,
            'processed_by': 'terraform-lab3-lambda'
        }

        metadata_key = f"metadata/{key}.json"

        s3.put_object(
            Bucket=bucket,
            Key=metadata_key,
            Body=json.dumps(metadata, indent=2),
            ContentType='application/json'
        )

        print(f"Created metadata: {metadata_key}")

    return {
        'statusCode': 200,
        'body': json.dumps('Processing complete!')
    }
EOF

# Create deployment package
cd lambda
zip -r ../function.zip .
cd ..
```

### Step 3: Create Terraform Configuration

```bash
cat > main.tf << 'EOF'
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# Random suffix
resource "random_id" "suffix" {
  byte_length = 4
}

# S3 Bucket for uploads
resource "aws_s3_bucket" "uploads" {
  bucket = "lab3-uploads-${random_id.suffix.hex}"

  tags = {
    Name = "Lab 3 Uploads"
    Lab  = "3"
  }
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda" {
  name = "lab3-lambda-role"

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

# Lambda basic execution policy
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# S3 access policy for Lambda
resource "aws_iam_role_policy" "lambda_s3" {
  name = "lambda-s3-access"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:HeadObject"
      ]
      Resource = "${aws_s3_bucket.uploads.arn}/*"
    }]
  })
}

# Lambda Function
resource "aws_lambda_function" "processor" {
  filename         = "function.zip"
  function_name    = "lab3-s3-processor"
  role            = aws_iam_role.lambda.arn
  handler         = "index.handler"
  runtime         = "python3.11"
  source_code_hash = filebase64sha256("function.zip")
  timeout          = 60

  environment {
    variables = {
      LAB = "3"
    }
  }

  tags = {
    Name = "Lab 3 Processor"
    Lab  = "3"
  }
}

# Lambda permission for S3
resource "aws_lambda_permission" "s3" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.uploads.arn
}

# S3 Bucket Notification
resource "aws_s3_bucket_notification" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.processor.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "uploads/"
  }

  depends_on = [aws_lambda_permission.s3]
}

# Outputs
output "bucket_name" {
  description = "Upload bucket name"
  value       = aws_s3_bucket.uploads.bucket
}

output "lambda_function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.processor.function_name
}

output "test_command" {
  description = "Command to test the setup"
  value       = "echo 'Test file' > test.txt && aws s3 cp test.txt s3://${aws_s3_bucket.uploads.bucket}/uploads/test.txt"
}
EOF
```

### Step 4: Deploy and Test

```bash
# Initialize
terraform init

# Apply
terraform apply -auto-approve

# Upload a test file
echo "Hello from Lab 3!" > test.txt
aws s3 cp test.txt s3://$(terraform output -raw bucket_name)/uploads/test.txt

# Wait a few seconds, then check for metadata file
sleep 5
aws s3 ls s3://$(terraform output -raw bucket_name)/metadata/

# Download and view metadata
aws s3 cp s3://$(terraform output -raw bucket_name)/metadata/uploads/test.txt.json - | jq .

# Check Lambda logs
aws logs tail /aws/lambda/$(terraform output -raw lambda_function_name) --follow
```

### Step 5: Upload Multiple Files

```bash
# Create and upload multiple files
for i in {1..5}; do
  echo "Test file $i" > test$i.txt
  aws s3 cp test$i.txt s3://$(terraform output -raw bucket_name)/uploads/
done

# Check metadata files
aws s3 ls s3://$(terraform output -raw bucket_name)/metadata/uploads/
```

### Step 6: Cleanup

```bash
# Empty bucket first (required before destroy)
aws s3 rm s3://$(terraform output -raw bucket_name) --recursive

# Destroy
terraform destroy -auto-approve
```

---

## Lab 4: Complete SageMaker Environment

**Goal:** Create SageMaker notebook with data storage.

**Time:** 60 minutes

**Prerequisites:**
- Completed previous labs
- Understanding of IAM roles

### Challenge

Create a complete setup with:
- S3 bucket for data
- SageMaker notebook instance
- Lifecycle configuration
- Proper IAM roles

Use the examples from `02-EXAMPLES.md` as reference.

**Bonus:** Add CloudWatch logging for the notebook.

---

## Lab 5: Full Application Stack

**Goal:** Combine everything learned.

**Time:** 90 minutes

### Requirements

Create infrastructure for a machine learning pipeline:

1. **VPC** with public and private subnets
2. **EC2** bastion host in public subnet
3. **SageMaker** notebook in private subnet
4. **S3** buckets for:
   - Raw data
   - Processed data
   - Model artifacts
5. **Lambda** for data processing
6. **IAM** roles with least privilege

### Deliverables

- Working Terraform code
- README with architecture diagram (ASCII art is fine)
- Outputs showing all resource IDs and endpoints
- Test procedure documented

---

## Next Steps

After completing these labs, you should be comfortable with:
- Terraform workflow
- AWS resource creation
- State management
- Troubleshooting

Continue learning with:
- Terraform modules
- Remote state
- CI/CD integration
- Multi-environment deployments

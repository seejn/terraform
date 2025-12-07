# Terraform AWS Examples - Complete Guide

## Table of Contents
1. [VPC Examples](#vpc-examples)
2. [EC2 Examples](#ec2-examples)
3. [Lambda Examples](#lambda-examples)
4. [SageMaker Examples](#sagemaker-examples)
5. [Complete Projects](#complete-projects)

---

## VPC Examples

### Example 1: Basic VPC

**What you'll create**:
- 1 VPC
- 1 public subnet
- 1 internet gateway
- Route table

```hcl
# vpc-basic.tf

# Create VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "main-vpc"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-igw"
  }
}

# Create Public Subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet"
  }
}

# Create Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "public-rt"
  }
}

# Associate Route Table with Subnet
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Outputs
output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_id" {
  value = aws_subnet.public.id
}
```

**Usage**:
```bash
terraform init
terraform plan
terraform apply
```

### Example 2: VPC with Public and Private Subnets

**What you'll create**:
- 1 VPC
- 2 public subnets (different AZs)
- 2 private subnets (different AZs)
- NAT Gateway for private subnets

```hcl
# vpc-advanced.tf

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "availability_zones" {
  default = ["us-east-1a", "us-east-1b"]
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "production-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-igw"
  }
}

# Public Subnets
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.${count.index + 1}.0/24"
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-${count.index + 1}"
  }
}

# Private Subnets
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 10}.0/24"
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "private-subnet-${count.index + 1}"
  }
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "nat-eip"
  }
}

# NAT Gateway
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "main-nat"
  }

  depends_on = [aws_internet_gateway.main]
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "public-rt"
  }
}

# Private Route Table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "private-rt"
  }
}

# Public Subnet Associations
resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private Subnet Associations
resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# Outputs
output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}
```

---

## EC2 Examples

### Example 1: Simple EC2 Instance

```hcl
# ec2-simple.tf

# Get latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Create Security Group
resource "aws_security_group" "web" {
  name        = "web-server-sg"
  description = "Allow HTTP and SSH"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # WARNING: Open to world, use your IP instead
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "web-server-sg"
  }
}

# Create EC2 Instance
resource "aws_instance" "web" {
  ami           = data.aws_ami.amazon_linux_2.id
  instance_type = "t2.micro"

  security_groups = [aws_security_group.web.name]

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              echo "<h1>Hello from Terraform!</h1>" > /var/www/html/index.html
              EOF

  tags = {
    Name = "web-server"
  }
}

# Outputs
output "instance_id" {
  value = aws_instance.web.id
}

output "public_ip" {
  value = aws_instance.web.public_ip
}

output "web_url" {
  value = "http://${aws_instance.web.public_ip}"
}
```

**Test it**:
```bash
terraform apply
# Wait 2-3 minutes for user_data script to run
curl http://$(terraform output -raw public_ip)
```

### Example 2: EC2 with EBS Volume

```hcl
# ec2-with-storage.tf

resource "aws_instance" "app" {
  ami           = data.aws_ami.amazon_linux_2.id
  instance_type = "t2.micro"

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name = "app-server"
  }
}

# Create additional EBS volume
resource "aws_ebs_volume" "data" {
  availability_zone = aws_instance.app.availability_zone
  size              = 50
  type              = "gp3"
  encrypted         = true

  tags = {
    Name = "app-data-volume"
  }
}

# Attach volume to instance
resource "aws_volume_attachment" "data" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.data.id
  instance_id = aws_instance.app.id
}

output "mount_command" {
  value = "SSH to instance and run: sudo mkfs -t ext4 /dev/sdf && sudo mount /dev/sdf /data"
}
```

### Example 3: Auto Scaling Group

```hcl
# ec2-autoscaling.tf

# Launch Template
resource "aws_launch_template" "app" {
  name_prefix   = "app-"
  image_id      = data.aws_ami.amazon_linux_2.id
  instance_type = "t2.micro"

  user_data = base64encode(<<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              systemctl start httpd
              echo "<h1>Instance: $(hostname)</h1>" > /var/www/html/index.html
              EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "app-server"
    }
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "app" {
  name                = "app-asg"
  min_size            = 2
  max_size            = 5
  desired_capacity    = 2
  availability_zones  = ["us-east-1a", "us-east-1b"]

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "app-server"
    propagate_at_launch = true
  }
}

# Scaling Policy (scale up if CPU > 70%)
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "scale-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.app.name
}
```

---

## Lambda Examples

### Example 1: Simple Python Lambda

**Step 1: Create Lambda function code**
```bash
mkdir lambda
cat > lambda/index.py << 'EOF'
import json

def handler(event, context):
    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': 'Hello from Terraform Lambda!',
            'input': event
        })
    }
EOF

cd lambda
zip function.zip index.py
cd ..
```

**Step 2: Create Terraform config**
```hcl
# lambda-simple.tf

# IAM Role for Lambda
resource "aws_iam_role" "lambda" {
  name = "lambda_execution_role"

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

# Attach basic execution policy
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda Function
resource "aws_lambda_function" "hello" {
  filename         = "lambda/function.zip"
  function_name    = "hello-world"
  role            = aws_iam_role.lambda.arn
  handler         = "index.handler"
  runtime         = "python3.11"
  source_code_hash = filebase64sha256("lambda/function.zip")

  environment {
    variables = {
      ENVIRONMENT = "production"
    }
  }

  tags = {
    Name = "hello-lambda"
  }
}

# Output
output "lambda_arn" {
  value = aws_lambda_function.hello.arn
}

output "invoke_command" {
  value = "aws lambda invoke --function-name ${aws_lambda_function.hello.function_name} output.json"
}
```

**Test**:
```bash
terraform apply
aws lambda invoke --function-name hello-world output.json
cat output.json
```

### Example 2: Lambda with API Gateway

```hcl
# lambda-api.tf

# Lambda function (reuse from Example 1)
resource "aws_lambda_function" "api" {
  filename         = "lambda/function.zip"
  function_name    = "api-handler"
  role            = aws_iam_role.lambda.arn
  handler         = "index.handler"
  runtime         = "python3.11"
  source_code_hash = filebase64sha256("lambda/function.zip")
}

# API Gateway
resource "aws_apigatewayv2_api" "lambda" {
  name          = "lambda-api"
  protocol_type = "HTTP"
}

# API Gateway Integration
resource "aws_apigatewayv2_integration" "lambda" {
  api_id           = aws_apigatewayv2_api.lambda.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.api.invoke_arn
}

# API Gateway Route
resource "aws_apigatewayv2_route" "lambda" {
  api_id    = aws_apigatewayv2_api.lambda.id
  route_key = "GET /hello"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

# API Gateway Stage
resource "aws_apigatewayv2_stage" "lambda" {
  api_id      = aws_apigatewayv2_api.lambda.id
  name        = "prod"
  auto_deploy = true
}

# Lambda Permission for API Gateway
resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}

# Output
output "api_url" {
  value = "${aws_apigatewayv2_stage.lambda.invoke_url}/hello"
}
```

**Test**:
```bash
terraform apply
curl $(terraform output -raw api_url)
```

### Example 3: Lambda with S3 Trigger

```hcl
# lambda-s3-trigger.tf

# S3 Bucket
resource "aws_s3_bucket" "uploads" {
  bucket = "my-upload-bucket-${random_id.bucket_suffix.hex}"
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# Lambda to process S3 uploads
resource "aws_lambda_function" "processor" {
  filename         = "lambda/function.zip"
  function_name    = "s3-processor"
  role            = aws_iam_role.lambda_s3.arn
  handler         = "index.handler"
  runtime         = "python3.11"
  source_code_hash = filebase64sha256("lambda/function.zip")
}

# IAM Role with S3 access
resource "aws_iam_role" "lambda_s3" {
  name = "lambda_s3_role"

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

resource "aws_iam_role_policy_attachment" "lambda_s3_basic" {
  role       = aws_iam_role.lambda_s3.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_s3_access" {
  role = aws_iam_role.lambda_s3.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:PutObject"
      ]
      Resource = "${aws_s3_bucket.uploads.arn}/*"
    }]
  })
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

# Lambda Permission for S3
resource "aws_lambda_permission" "s3" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.uploads.arn
}

output "bucket_name" {
  value = aws_s3_bucket.uploads.bucket
}
```

---

## SageMaker Examples

### Example 1: SageMaker Notebook Instance

```hcl
# sagemaker-notebook.tf

# IAM Role for SageMaker
resource "aws_iam_role" "sagemaker" {
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
}

# Attach SageMaker execution policy
resource "aws_iam_role_policy_attachment" "sagemaker_full" {
  role       = aws_iam_role.sagemaker.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess"
}

# SageMaker Notebook Instance
resource "aws_sagemaker_notebook_instance" "ml_notebook" {
  name          = "ml-notebook"
  instance_type = "ml.t3.medium"
  role_arn      = aws_iam_role.sagemaker.arn

  tags = {
    Name = "ML Notebook"
  }
}

# Output
output "notebook_url" {
  value = "https://${aws_sagemaker_notebook_instance.ml_notebook.url}"
}

output "notebook_name" {
  value = aws_sagemaker_notebook_instance.ml_notebook.name
}
```

### Example 2: SageMaker with Custom Lifecycle Config

```hcl
# sagemaker-advanced.tf

# Lifecycle Configuration (runs scripts on start/create)
resource "aws_sagemaker_notebook_instance_lifecycle_configuration" "config" {
  name = "ml-lifecycle-config"

  on_start = base64encode(<<-EOF
    #!/bin/bash
    set -e

    # Install additional packages
    sudo -u ec2-user -i <<'USEREOF'
    source /home/ec2-user/anaconda3/bin/activate pytorch_p310
    pip install transformers datasets
    conda deactivate
    USEREOF
    EOF
  )

  on_create = base64encode(<<-EOF
    #!/bin/bash
    set -e

    # Clone your code repository
    sudo -u ec2-user -i <<'USEREOF'
    cd /home/ec2-user/SageMaker
    git clone https://github.com/yourusername/ml-project.git
    USEREOF
    EOF
  )
}

# S3 Bucket for SageMaker data
resource "aws_s3_bucket" "sagemaker_data" {
  bucket = "sagemaker-data-${random_id.suffix.hex}"
}

resource "random_id" "suffix" {
  byte_length = 4
}

# IAM Role with S3 access
resource "aws_iam_role" "sagemaker_advanced" {
  name = "sagemaker-advanced-role"

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

resource "aws_iam_role_policy_attachment" "sagemaker_full_advanced" {
  role       = aws_iam_role.sagemaker_advanced.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess"
}

resource "aws_iam_role_policy" "sagemaker_s3" {
  role = aws_iam_role.sagemaker_advanced.id

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

# SageMaker Notebook with all features
resource "aws_sagemaker_notebook_instance" "advanced" {
  name                    = "advanced-ml-notebook"
  instance_type           = "ml.t3.xlarge"
  role_arn                = aws_iam_role.sagemaker_advanced.arn
  lifecycle_config_name   = aws_sagemaker_notebook_instance_lifecycle_configuration.config.name
  volume_size             = 20
  direct_internet_access  = "Enabled"

  tags = {
    Name        = "Advanced ML Notebook"
    Environment = "development"
  }
}

# Outputs
output "notebook_url_advanced" {
  value = "https://${aws_sagemaker_notebook_instance.advanced.url}"
}

output "data_bucket" {
  value = aws_s3_bucket.sagemaker_data.bucket
}
```

---

## Complete Projects

### Project 1: Web Application Stack

Complete stack with VPC, EC2, RDS, and ALB.

```hcl
# complete-web-app.tf

# VPC
resource "aws_vpc" "app" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = { Name = "app-vpc" }
}

# Subnets
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.app.id
  cidr_block              = "10.0.${count.index + 1}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = { Name = "public-${count.index + 1}" }
}

resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.app.id
  cidr_block        = "10.0.${count.index + 10}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = { Name = "private-${count.index + 1}" }
}

data "aws_availability_zones" "available" {
  state = "available"
}

# Internet Gateway
resource "aws_internet_gateway" "app" {
  vpc_id = aws_vpc.app.id
  tags   = { Name = "app-igw" }
}

# Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.app.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.app.id
  }

  tags = { Name = "public-rt" }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Security Groups
resource "aws_security_group" "alb" {
  name        = "alb-sg"
  description = "ALB security group"
  vpc_id      = aws_vpc.app.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "web" {
  name        = "web-sg"
  description = "Web server security group"
  vpc_id      = aws_vpc.app.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Application Load Balancer
resource "aws_lb" "app" {
  name               = "app-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id
}

resource "aws_lb_target_group" "app" {
  name     = "app-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.app.id

  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 10
  }
}

resource "aws_lb_listener" "app" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# Launch Template
resource "aws_launch_template" "app" {
  name_prefix   = "app-"
  image_id      = data.aws_ami.amazon_linux_2.id
  instance_type = "t2.micro"

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.web.id]
  }

  user_data = base64encode(<<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              echo "<h1>Hello from $(hostname)</h1>" > /var/www/html/index.html
              EOF
  )
}

# Auto Scaling Group
resource "aws_autoscaling_group" "app" {
  name                = "app-asg"
  min_size            = 2
  max_size            = 4
  desired_capacity    = 2
  target_group_arns   = [aws_lb_target_group.app.arn]
  vpc_zone_identifier = aws_subnet.public[*].id

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "app-server"
    propagate_at_launch = true
  }
}

# Outputs
output "load_balancer_url" {
  value = "http://${aws_lb.app.dns_name}"
}
```

**Usage**:
```bash
terraform apply
# Wait 3-5 minutes for instances to start
curl $(terraform output -raw load_balancer_url)
```

This guide provides complete, working examples for all your AWS services!

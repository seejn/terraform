# Terraform Best Practices

## Table of Contents
1. [Project Structure](#project-structure)
2. [Naming Conventions](#naming-conventions)
3. [Variable Management](#variable-management)
4. [State Management](#state-management)
5. [Security Best Practices](#security-best-practices)
6. [Code Organization](#code-organization)
7. [Common Patterns](#common-patterns)

---

## Project Structure

### Small Projects (Single Environment)

```
terraform-project/
├── main.tf           # Main resource definitions
├── variables.tf      # Variable declarations
├── outputs.tf        # Output values
├── terraform.tfvars  # Variable values (gitignored)
├── provider.tf       # Provider configuration
└── .gitignore       # Terraform-specific gitignore
```

### Medium Projects (Multiple Environments)

```
terraform-project/
├── modules/
│   ├── vpc/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── ec2/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── lambda/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
├── environments/
│   ├── dev/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── terraform.tfvars
│   │   └── backend.tf
│   ├── staging/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── terraform.tfvars
│   │   └── backend.tf
│   └── prod/
│       ├── main.tf
│       ├── variables.tf
│       ├── terraform.tfvars
│       └── backend.tf
└── README.md
```

### Large Projects (Enterprise)

```
terraform-monorepo/
├── modules/              # Reusable modules
│   ├── networking/
│   ├── compute/
│   ├── database/
│   └── security/
├── projects/            # Different projects/applications
│   ├── web-app/
│   │   ├── dev/
│   │   ├── staging/
│   │   └── prod/
│   └── api-service/
│       ├── dev/
│       ├── staging/
│       └── prod/
├── global/              # Shared resources (IAM, S3 for state)
│   └── iam/
└── scripts/             # Helper scripts
    ├── deploy.sh
    └── destroy.sh
```

---

## Naming Conventions

### Resource Names

**Use descriptive, consistent names:**

```hcl
# BAD
resource "aws_instance" "i1" { ... }
resource "aws_vpc" "v" { ... }

# GOOD
resource "aws_instance" "web_server" { ... }
resource "aws_vpc" "main" { ... }
```

**Follow a pattern:**

```hcl
# Pattern: <purpose>_<component>
resource "aws_instance" "app_server" { ... }
resource "aws_lb" "app_load_balancer" { ... }
resource "aws_db_instance" "app_database" { ... }
```

### Tag Names

**Always tag resources:**

```hcl
resource "aws_instance" "web" {
  ami           = "ami-12345678"
  instance_type = "t2.micro"

  tags = {
    Name        = "web-server-prod"
    Environment = "production"
    Project     = "ecommerce"
    ManagedBy   = "terraform"
    Owner       = "devops-team"
    CostCenter  = "engineering"
  }
}
```

**Use consistent tag structure across all resources:**

```hcl
# variables.tf
variable "common_tags" {
  type = map(string)
  default = {
    ManagedBy   = "terraform"
    Environment = "production"
    Project     = "my-app"
  }
}

# main.tf
resource "aws_instance" "web" {
  # ... other config ...

  tags = merge(
    var.common_tags,
    {
      Name = "web-server"
      Role = "webserver"
    }
  )
}
```

### File Names

```
main.tf              # Primary resources
variables.tf         # Variable declarations
outputs.tf           # Outputs
provider.tf          # Provider configuration
backend.tf           # Backend configuration
data.tf              # Data sources
locals.tf            # Local values

# Or organize by service:
vpc.tf
ec2.tf
lambda.tf
sagemaker.tf
iam.tf
security-groups.tf
```

---

## Variable Management

### Variable Declarations

**Always include descriptions and types:**

```hcl
# BAD
variable "region" {}
variable "count" {}

# GOOD
variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "us-east-1"
}

variable "instance_count" {
  description = "Number of EC2 instances to create"
  type        = number
  default     = 2

  validation {
    condition     = var.instance_count >= 1 && var.instance_count <= 10
    error_message = "Instance count must be between 1 and 10."
  }
}
```

### Variable Types

```hcl
# String
variable "environment" {
  type    = string
  default = "dev"
}

# Number
variable "instance_count" {
  type    = number
  default = 2
}

# Boolean
variable "enable_monitoring" {
  type    = bool
  default = false
}

# List
variable "availability_zones" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b"]
}

# Map
variable "instance_types" {
  type = map(string)
  default = {
    dev  = "t2.micro"
    prod = "t3.large"
  }
}

# Object
variable "vpc_config" {
  type = object({
    cidr_block           = string
    enable_dns_hostnames = bool
    enable_dns_support   = bool
  })
  default = {
    cidr_block           = "10.0.0.0/16"
    enable_dns_hostnames = true
    enable_dns_support   = true
  }
}
```

### Sensitive Variables

```hcl
variable "database_password" {
  description = "Database master password"
  type        = string
  sensitive   = true
}

# Don't put sensitive values in .tf files!
# Use environment variables or terraform.tfvars (gitignored)
```

**Set via environment:**
```bash
export TF_VAR_database_password="super-secret-password"
terraform apply
```

**Or use terraform.tfvars (add to .gitignore):**
```hcl
# terraform.tfvars
database_password = "super-secret-password"
```

---

## State Management

### Remote State (Production)

**Always use remote state for team projects:**

```hcl
# backend.tf
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "projects/web-app/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}
```

**Setup steps:**

1. Create S3 bucket for state:
```hcl
# bootstrap/main.tf
resource "aws_s3_bucket" "terraform_state" {
  bucket = "my-terraform-state"
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_dynamodb_table" "terraform_locks" {
  name         = "terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
```

2. Apply bootstrap:
```bash
cd bootstrap
terraform init
terraform apply
cd ..
```

3. Configure backend in your project:
```hcl
# backend.tf
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "project/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}
```

### State Best Practices

1. **Never edit state files manually**
2. **Use state locking** (DynamoDB with S3 backend)
3. **Enable versioning** on state bucket
4. **Encrypt state** (contains sensitive data)
5. **Separate states** for different environments
6. **Use workspaces** or separate directories for environments

---

## Security Best Practices

### 1. Never Hardcode Credentials

```hcl
# BAD - Don't do this!
provider "aws" {
  access_key = "AKIAIOSFODNN7EXAMPLE"
  secret_key = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
}

# GOOD - Use AWS CLI configuration or IAM roles
provider "aws" {
  region = "us-east-1"
  # Credentials from ~/.aws/credentials or EC2 instance role
}
```

### 2. Use IAM Roles Instead of Keys

```hcl
# For EC2 instances
resource "aws_iam_instance_profile" "app" {
  name = "app-profile"
  role = aws_iam_role.app.name
}

resource "aws_instance" "app" {
  ami                  = "ami-12345678"
  instance_type        = "t2.micro"
  iam_instance_profile = aws_iam_instance_profile.app.name
}
```

### 3. Principle of Least Privilege

```hcl
# BAD - Too permissive
resource "aws_iam_role_policy" "bad" {
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "*"
      Resource = "*"
    }]
  })
}

# GOOD - Specific permissions
resource "aws_iam_role_policy" "good" {
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:PutObject"
      ]
      Resource = "arn:aws:s3:::my-bucket/*"
    }]
  })
}
```

### 4. Encrypt Everything

```hcl
# EBS volumes
resource "aws_instance" "app" {
  ami           = "ami-12345678"
  instance_type = "t2.micro"

  root_block_device {
    encrypted = true
  }
}

# S3 buckets
resource "aws_s3_bucket_server_side_encryption_configuration" "data" {
  bucket = aws_s3_bucket.data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# RDS databases
resource "aws_db_instance" "app" {
  # ... other config ...
  storage_encrypted = true
}
```

### 5. Restrict Security Groups

```hcl
# BAD - Open to the world
resource "aws_security_group" "bad" {
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# GOOD - Restricted to specific IPs
resource "aws_security_group" "good" {
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]  # VPN or office IP
    description = "SSH from corporate network"
  }
}
```

---

## Code Organization

### Use Modules for Reusability

**Module structure:**
```
modules/
└── web-server/
    ├── main.tf
    ├── variables.tf
    └── outputs.tf
```

**modules/web-server/main.tf:**
```hcl
resource "aws_instance" "web" {
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = var.subnet_id

  tags = {
    Name = var.server_name
  }
}
```

**modules/web-server/variables.tf:**
```hcl
variable "ami_id" {
  type = string
}

variable "instance_type" {
  type    = string
  default = "t2.micro"
}

variable "subnet_id" {
  type = string
}

variable "server_name" {
  type = string
}
```

**modules/web-server/outputs.tf:**
```hcl
output "instance_id" {
  value = aws_instance.web.id
}

output "public_ip" {
  value = aws_instance.web.public_ip
}
```

**Use the module:**
```hcl
# main.tf
module "web_server_1" {
  source = "./modules/web-server"

  ami_id        = "ami-12345678"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public.id
  server_name   = "web-1"
}

module "web_server_2" {
  source = "./modules/web-server"

  ami_id        = "ami-12345678"
  instance_type = "t2.small"
  subnet_id     = aws_subnet.public.id
  server_name   = "web-2"
}

output "web1_ip" {
  value = module.web_server_1.public_ip
}
```

### Use Locals for Computed Values

```hcl
locals {
  environment = terraform.workspace

  common_tags = {
    Environment = local.environment
    ManagedBy   = "terraform"
    Project     = var.project_name
  }

  # Computed values
  db_name = "${var.project_name}-${local.environment}-db"

  # Conditional values
  instance_type = local.environment == "prod" ? "t3.large" : "t2.micro"
}

resource "aws_instance" "app" {
  instance_type = local.instance_type
  tags          = local.common_tags
}
```

---

## Common Patterns

### 1. Count for Multiple Similar Resources

```hcl
variable "availability_zones" {
  default = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

resource "aws_subnet" "public" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 1}.0/24"
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "public-subnet-${count.index + 1}"
  }
}

# Reference: aws_subnet.public[0].id, aws_subnet.public[1].id, etc.
```

### 2. For_Each for Different Resources

```hcl
variable "users" {
  type = map(object({
    email = string
    role  = string
  }))
  default = {
    "alice" = {
      email = "alice@example.com"
      role  = "admin"
    }
    "bob" = {
      email = "bob@example.com"
      role  = "developer"
    }
  }
}

resource "aws_iam_user" "users" {
  for_each = var.users
  name     = each.key

  tags = {
    Email = each.value.email
    Role  = each.value.role
  }
}

# Reference: aws_iam_user.users["alice"].arn
```

### 3. Dynamic Blocks

```hcl
variable "ingress_rules" {
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
  default = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/8"]
    },
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}

resource "aws_security_group" "web" {
  name = "web-sg"

  dynamic "ingress" {
    for_each = var.ingress_rules
    content {
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }
}
```

### 4. Conditional Resources

```hcl
variable "create_monitoring" {
  type    = bool
  default = false
}

resource "aws_cloudwatch_metric_alarm" "cpu" {
  count = var.create_monitoring ? 1 : 0

  alarm_name          = "high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "80"
}
```

---

## Formatting and Linting

```bash
# Format code
terraform fmt -recursive

# Validate syntax
terraform validate

# Use tflint for advanced linting
brew install tflint  # or appropriate package manager
tflint
```

---

## Version Control

**.gitignore:**
```
# Local state
*.tfstate
*.tfstate.*

# Crash logs
crash.log

# Variables with sensitive data
*.tfvars
!example.tfvars

# CLI configuration
.terraformrc
terraform.rc

# Module directory
.terraform/
.terraform.lock.hcl

# Override files
override.tf
override.tf.json
```

**Commit messages:**
```bash
git commit -m "feat: add VPC with public/private subnets"
git commit -m "fix: update security group to restrict SSH"
git commit -m "refactor: extract EC2 module"
```

---

These best practices will help you write maintainable, secure, and scalable Terraform code!

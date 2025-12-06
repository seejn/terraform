# Terraform Core Concepts - Deep Dive

## Table of Contents
1. [What is Infrastructure as Code?](#what-is-infrastructure-as-code)
2. [How Terraform Works](#how-terraform-works)
3. [Terraform Language (HCL)](#terraform-language-hcl)
4. [State Management](#state-management)
5. [Resource Dependencies](#resource-dependencies)
6. [Providers](#providers)

---

## What is Infrastructure as Code?

### Traditional Way (Manual)
```
You → AWS Console → Click buttons → Create EC2 instance
                  → Click more buttons → Create VPC
                  → Remember what you did → Document in wiki
```

**Problems**:
- Hard to reproduce
- Easy to make mistakes
- No version history
- Manual documentation required
- Can't automate

### Infrastructure as Code Way (Terraform)
```
You → Write main.tf → Git commit → terraform apply → Everything created
```

**Benefits**:
- Reproducible (same code = same infrastructure)
- Version controlled (git history)
- Automated (CI/CD pipelines)
- Self-documenting (code IS the documentation)
- Testable

### Real Example

**Manual**: "I created a VPC with CIDR 10.0.0.0/16, then created 2 subnets, attached an internet gateway, configured route tables..."

**Terraform**:
```hcl
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}
```
Done. Terraform knows what else is needed.

---

## How Terraform Works

### The Complete Lifecycle

```
┌─────────────────────────────────────────────────────────────┐
│ 1. WRITE CODE (.tf files)                                   │
│    - Define what you want                                   │
└─────────────────────────┬───────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ 2. TERRAFORM INIT                                           │
│    - Downloads providers (AWS, Azure, etc.)                 │
│    - Sets up backend (where state is stored)                │
└─────────────────────────┬───────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ 3. TERRAFORM PLAN                                           │
│    - Reads your .tf files                                   │
│    - Reads current state file                               │
│    - Calls AWS API to check what exists                     │
│    - Compares: desired state vs actual state                │
│    - Creates execution plan                                 │
└─────────────────────────┬───────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ 4. TERRAFORM APPLY                                          │
│    - Executes the plan                                      │
│    - Creates/updates/deletes resources via AWS API          │
│    - Updates state file                                     │
└─────────────────────────┬───────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ 5. STATE FILE UPDATED                                       │
│    - terraform.tfstate now matches reality                  │
└─────────────────────────────────────────────────────────────┘
```

### Example: Creating an S3 Bucket

**Step 1: You write**
```hcl
resource "aws_s3_bucket" "data" {
  bucket = "my-data-bucket"
}
```

**Step 2: Terraform Plan**
- Terraform: "State file says: no bucket exists"
- Terraform: "Code says: bucket should exist"
- Terraform: "Conclusion: I need to CREATE this bucket"

**Step 3: Terraform Apply**
- Terraform calls AWS API: `CreateBucket("my-data-bucket")`
- AWS responds: "Created successfully"
- Terraform updates state file: "bucket exists with ID xyz"

**Step 4: You change the code**
```hcl
resource "aws_s3_bucket" "data" {
  bucket = "my-data-bucket"

  tags = {
    Environment = "production"
  }
}
```

**Step 5: Terraform Plan**
- Terraform: "State file says: bucket exists, no tags"
- Terraform: "Code says: bucket should have tags"
- Terraform: "Conclusion: I need to UPDATE this bucket"

**Step 6: Terraform Apply**
- Terraform calls AWS API: `TagBucket("my-data-bucket", tags)`
- AWS responds: "Updated successfully"
- Terraform updates state file: "bucket exists with tags"

---

## Terraform Language (HCL)

HCL = HashiCorp Configuration Language

### Basic Syntax

```hcl
# This is a comment

// This is also a comment

/* This is a
   multi-line comment */

# Block structure
<BLOCK_TYPE> "<LABEL>" "<NAME>" {
  argument1 = value1
  argument2 = value2

  nested_block {
    setting = "value"
  }
}
```

### 1. Resource Blocks

**Format**:
```hcl
resource "resource_type" "local_name" {
  argument = value
}
```

**Example**:
```hcl
resource "aws_instance" "web_server" {
  ami           = "ami-12345678"
  instance_type = "t2.micro"

  tags = {
    Name = "WebServer"
  }
}
```

**Breakdown**:
- `resource` = keyword (always the same)
- `"aws_instance"` = resource type (from AWS provider)
- `"web_server"` = YOUR name for this resource (any name you want)
- Inside `{}` = configuration arguments

**Reference this resource elsewhere**:
```hcl
# Format: resource_type.local_name.attribute
aws_instance.web_server.id
aws_instance.web_server.public_ip
```

### 2. Variable Blocks

**Define**:
```hcl
variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "instance_count" {
  description = "Number of instances"
  type        = number
  default     = 2
}

variable "enable_monitoring" {
  description = "Enable detailed monitoring"
  type        = bool
  default     = false
}
```

**Use**:
```hcl
provider "aws" {
  region = var.region
}

resource "aws_instance" "app" {
  count         = var.instance_count
  monitoring    = var.enable_monitoring
}
```

**Set values when running**:
```bash
# Command line
terraform apply -var="region=us-west-2" -var="instance_count=5"

# Or create terraform.tfvars file
echo 'region = "us-west-2"' >> terraform.tfvars
terraform apply
```

### 3. Output Blocks

**Define**:
```hcl
output "instance_ip" {
  description = "Public IP of the instance"
  value       = aws_instance.web_server.public_ip
}

output "bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.data.bucket
}
```

**View outputs**:
```bash
terraform output
# Shows all outputs

terraform output instance_ip
# Shows just the instance IP
```

**Use in automation**:
```bash
# Get output as JSON
terraform output -json

# Use in scripts
IP=$(terraform output -raw instance_ip)
ssh ubuntu@$IP
```

### 4. Data Sources

Data sources let you **read** existing resources (not create them).

```hcl
# Get the latest Amazon Linux 2 AMI
data "aws_ami" "latest_amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Use the AMI ID
resource "aws_instance" "server" {
  ami = data.aws_ami.latest_amazon_linux.id
}
```

### 5. Local Values

Like variables, but computed from other values.

```hcl
locals {
  common_tags = {
    Environment = "production"
    ManagedBy   = "terraform"
    Project     = "web-app"
  }

  bucket_name = "${var.project_name}-data-${var.environment}"
}

resource "aws_s3_bucket" "data" {
  bucket = local.bucket_name
  tags   = local.common_tags
}
```

---

## State Management

### What is the State File?

The state file (`terraform.tfstate`) is Terraform's database of what it created.

**Example state file** (simplified):
```json
{
  "resources": [
    {
      "type": "aws_instance",
      "name": "web_server",
      "instances": [{
        "attributes": {
          "id": "i-1234567890abcdef0",
          "public_ip": "54.123.45.67",
          "instance_type": "t2.micro"
        }
      }]
    }
  ]
}
```

### Why State is Important

**Without state**:
- Terraform: "Should I create this EC2 instance?"
- You: "I don't know, did you already create it?"
- Terraform: "I don't remember..."

**With state**:
- Terraform: "State says I created instance i-1234. Let me check if it still exists."
- AWS API: "Yes, it exists"
- Terraform: "Great, nothing to do!"

### State Commands

```bash
# List all resources in state
terraform state list

# Show details of a resource
terraform state show aws_instance.web_server

# Remove a resource from state (doesn't delete it)
terraform state rm aws_instance.web_server

# Move/rename a resource
terraform state mv aws_instance.old aws_instance.new
```

### Local vs Remote State

**Local State** (default):
- State file stored in your project folder
- OK for learning/testing
- BAD for teams (can't share state)

**Remote State** (recommended for production):
```hcl
terraform {
  backend "s3" {
    bucket = "my-terraform-state"
    key    = "project/terraform.tfstate"
    region = "us-east-1"
  }
}
```

Benefits:
- Shared across team
- Locked during operations (prevents conflicts)
- Backed up automatically
- Encrypted

---

## Resource Dependencies

Terraform automatically figures out the order to create things.

### Implicit Dependencies

Terraform detects these automatically:

```hcl
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.main.id  # References VPC
  cidr_block = "10.0.1.0/24"
}

resource "aws_instance" "web" {
  subnet_id = aws_subnet.public.id  # References subnet
  ami       = "ami-12345678"
  instance_type = "t2.micro"
}
```

**Terraform's logic**:
1. "Instance needs subnet"
2. "Subnet needs VPC"
3. "So I'll create: VPC → Subnet → Instance"

### Explicit Dependencies

Sometimes Terraform can't detect dependencies automatically:

```hcl
resource "aws_instance" "app" {
  ami           = "ami-12345678"
  instance_type = "t2.micro"

  # Force this instance to wait for S3 bucket
  depends_on = [aws_s3_bucket.data]
}

resource "aws_s3_bucket" "data" {
  bucket = "app-data-bucket"
}
```

### Dependency Graph

See the graph:
```bash
terraform graph | dot -Tpng > graph.png
```

---

## Providers

Providers are plugins that let Terraform talk to different services.

### Available Providers

- **aws** - Amazon Web Services
- **azurerm** - Microsoft Azure
- **google** - Google Cloud Platform
- **kubernetes** - Kubernetes
- **docker** - Docker
- **github** - GitHub
- 1000+ more at https://registry.terraform.io

### Provider Configuration

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"  # Use 5.x versions
    }
  }
}

provider "aws" {
  region = "us-east-1"

  # Optional: use specific credentials
  profile = "my-aws-profile"

  # Optional: default tags for ALL resources
  default_tags {
    tags = {
      ManagedBy = "Terraform"
      Owner     = "DevOps Team"
    }
  }
}
```

### Multiple Providers (Different Regions)

```hcl
provider "aws" {
  alias  = "east"
  region = "us-east-1"
}

provider "aws" {
  alias  = "west"
  region = "us-west-2"
}

# Use specific provider
resource "aws_instance" "east_server" {
  provider = aws.east
  ami      = "ami-12345678"
  instance_type = "t2.micro"
}

resource "aws_instance" "west_server" {
  provider = aws.west
  ami      = "ami-87654321"
  instance_type = "t2.micro"
}
```

---

## Summary

| Concept | What It Is | Example |
|---------|-----------|---------|
| Resource | Thing you want to create | `aws_instance`, `aws_s3_bucket` |
| Variable | Input parameter | `var.region` |
| Output | Value to display | `output "ip"` |
| Data Source | Read existing resource | `data "aws_ami"` |
| State | Terraform's memory | `terraform.tfstate` |
| Provider | Plugin for cloud service | `provider "aws"` |
| Dependency | Order of creation | VPC before Subnet |

---

## Next Steps

Now that you understand the concepts, move on to:
- **02-EXAMPLES.md** - Practical examples for each AWS service
- **03-BEST-PRACTICES.md** - How to write good Terraform code
- **04-TROUBLESHOOTING.md** - Fix common problems

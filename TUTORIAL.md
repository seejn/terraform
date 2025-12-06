# Terraform Tutorial - Complete Beginner Guide

## What is Terraform in Simple Terms?

Think of Terraform like a **recipe for cloud infrastructure**.

- Instead of clicking buttons in AWS console, you write a text file describing what you want
- Terraform reads your file and creates everything automatically
- You can delete everything just as easily

**Analogy**: It's like LEGO instructions. You describe what pieces go where, and Terraform builds it.

---

## Step 1: Install Terraform (5 minutes)

```bash
# Install Terraform on Linux
sudo snap install terraform --classic

# Verify it worked
terraform version
```

You should see something like: `Terraform v1.x.x`

---

## Step 2: Set Up AWS Credentials (5 minutes)

Terraform needs permission to create things in your AWS account.

```bash
# Install AWS CLI if you don't have it
sudo apt install awscli -y

# Configure your credentials
aws configure
```

It will ask for:
- **AWS Access Key ID**: (get from AWS Console → IAM)
- **AWS Secret Access Key**: (get from AWS Console → IAM)
- **Region**: type `us-east-1` (or your preferred region)
- **Output format**: just press Enter

---

## Step 3: Your First Terraform File (10 minutes)

Let's start SUPER simple - just create one S3 bucket.

Create a file called `simple.tf`:

```hcl
# Tell Terraform we're using AWS
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

# Create one S3 bucket
resource "aws_s3_bucket" "my_first_bucket" {
  bucket = "my-terraform-test-bucket-12345"  # Must be globally unique!

  tags = {
    Name = "My First Terraform Bucket"
  }
}
```

**Change the bucket name** to something unique (add your name or random numbers).

---

## Step 4: The Magic Three Commands

Now run these three commands in order:

### Command 1: Initialize
```bash
terraform init
```
**What it does**: Downloads the AWS "plugin" so Terraform can talk to AWS.
**You only run this once** per project.

### Command 2: Plan
```bash
terraform plan
```
**What it does**: Shows you what Terraform WILL do (without doing it yet).
**Output**: You'll see it wants to create (+) 1 S3 bucket.

### Command 3: Apply
```bash
terraform apply
```
**What it does**: Actually creates the resources.
**It will ask**: Type `yes` to confirm.

---

## Step 5: Check Your Work

```bash
# List what Terraform created
terraform show

# Or check AWS directly
aws s3 ls | grep my-terraform-test-bucket
```

Go to AWS Console → S3, and you'll see your bucket!

---

## Step 6: Destroy Everything

When you're done testing:

```bash
terraform destroy
```

Type `yes` - and Terraform deletes everything it created. Clean slate!

---

## Understanding the Workflow

```
Write .tf file → terraform init → terraform plan → terraform apply
                                                         ↓
                                                   AWS creates resources
                                                         ↓
                                              terraform destroy (cleanup)
```

---

## Next Level: Create an EC2 Instance

Once you're comfortable with the S3 example, try this `ec2.tf`:

```hcl
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

# Create an EC2 instance
resource "aws_instance" "my_server" {
  ami           = "ami-0c55b159cbfafe1f0"  # Amazon Linux 2
  instance_type = "t2.micro"              # Free tier eligible

  tags = {
    Name = "MyFirstServer"
  }
}

# Show the public IP after creation
output "server_ip" {
  value = aws_instance.my_server.public_ip
}
```

Same commands: `terraform init` → `terraform plan` → `terraform apply`

---

## Key Terraform Concepts

### 1. Resources
**What**: The things you want to create (S3 bucket, EC2 instance, VPC, etc.)
**Syntax**: `resource "TYPE" "NAME" { ... }`

### 2. Provider
**What**: Which cloud service (AWS, Azure, Google Cloud)
**Syntax**: `provider "aws" { region = "..." }`

### 3. State File
**What**: Terraform's memory of what it created
**File**: `terraform.tfstate` (don't edit manually!)
**Purpose**: Tracks what exists so Terraform knows what to update/delete

### 4. Variables
**What**: Make your code reusable
**Example**:
```hcl
variable "region" {
  default = "us-east-1"
}

provider "aws" {
  region = var.region
}
```

### 5. Outputs
**What**: Display useful info after creation (like IP addresses)
**Example**:
```hcl
output "bucket_name" {
  value = aws_s3_bucket.my_first_bucket.bucket
}
```

---

## Practice Exercise

Try this progression:

1. **Day 1**: Create S3 bucket, destroy it, recreate it
2. **Day 2**: Create EC2 instance, SSH into it, destroy it
3. **Day 3**: Create VPC with subnet
4. **Day 4**: Combine VPC + EC2 (EC2 inside the VPC)
5. **Day 5**: Add Lambda function
6. **Day 6**: Add SageMaker notebook

---

## Common Commands Cheat Sheet

```bash
terraform init          # Setup project (run once)
terraform fmt           # Format your code nicely
terraform validate      # Check for syntax errors
terraform plan          # Preview changes
terraform apply         # Create/update resources
terraform destroy       # Delete everything
terraform show          # See current state
terraform output        # Show output values
```

---

## Important Rules

1. **Always run `terraform plan` before `apply`** - preview is free and safe
2. **Don't edit `.tfstate` files** - let Terraform manage them
3. **Use unique names** - especially for S3 buckets (globally unique)
4. **Start small** - one resource at a time
5. **Destroy when done testing** - avoid AWS charges

---

## Your Learning Path

```
Week 1: Master init → plan → apply → destroy
Week 2: Practice with S3, EC2, basic networking
Week 3: Learn variables and outputs
Week 4: Build complete environments (VPC + EC2 + Lambda)
```

---

## Need Help?

- Official docs: https://registry.terraform.io/providers/hashicorp/aws/latest/docs
- Each resource has examples you can copy/paste
- Search: "terraform aws [resource-name] example"

---

## What You've Learned

- Terraform turns infrastructure into code
- Three core commands: init, plan, apply
- Resources are the things you create
- State file tracks what exists
- Destroy cleans up everything

**Next**: Try the S3 bucket example above!

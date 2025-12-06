# Terraform Troubleshooting Guide

## Table of Contents
1. [Common Errors](#common-errors)
2. [State Issues](#state-issues)
3. [Provider Issues](#provider-issues)
4. [Resource Errors](#resource-errors)
5. [Debugging Techniques](#debugging-techniques)
6. [Recovery Procedures](#recovery-procedures)

---

## Common Errors

### Error: "No configuration files"

**Problem:**
```
Error: No configuration files

No configuration files were found in the directory.
```

**Solution:**
```bash
# Make sure you're in the correct directory
ls *.tf

# If no .tf files exist, create main.tf
nano main.tf
```

---

### Error: "terraform.tfstate.lock.info"

**Problem:**
```
Error: Error acquiring the state lock

Error message: ConditionalCheckFailedException: The conditional request failed
Lock Info:
  ID:        abc123...
  Path:      terraform.tfstate
  Operation: OperationTypeApply
```

**Cause:** Someone else is running Terraform, or a previous run didn't complete.

**Solution:**
```bash
# Wait for other operations to complete, OR
# If you're sure no one else is using it:
terraform force-unlock abc123

# Replace abc123 with the Lock ID from the error
```

---

### Error: "Invalid provider configuration"

**Problem:**
```
Error: Invalid provider configuration

Provider "aws" requires configuration.
```

**Solution:**
```bash
# Configure AWS CLI
aws configure
AWS Access Key ID: YOUR_KEY
AWS Secret Access Key: YOUR_SECRET
Default region: us-east-1

# Or set environment variables
export AWS_ACCESS_KEY_ID="your-key"
export AWS_SECRET_ACCESS_KEY="your-secret"
export AWS_DEFAULT_REGION="us-east-1"

# Verify
aws sts get-caller-identity
```

---

### Error: "Resource already exists"

**Problem:**
```
Error: Error creating S3 bucket: BucketAlreadyExists: The requested bucket name is not available
```

**Cause:** S3 bucket names are globally unique.

**Solution:**
```hcl
# Change bucket name to something unique
resource "aws_s3_bucket" "data" {
  bucket = "my-unique-bucket-name-${random_id.suffix.hex}"
}

resource "random_id" "suffix" {
  byte_length = 4
}
```

---

### Error: "Invalid count argument"

**Problem:**
```
Error: Invalid count argument

The "count" value depends on resource attributes that cannot be determined until apply
```

**Cause:** Using count with computed values.

**Solution:**
```hcl
# BAD
resource "aws_subnet" "private" {
  count  = length(aws_subnet.public)  # Don't use computed values
}

# GOOD - Use variable
variable "subnet_count" {
  default = 2
}

resource "aws_subnet" "private" {
  count  = var.subnet_count
}
```

---

### Error: "Error launching source instance: InvalidAMIID.NotFound"

**Problem:**
```
Error: Error launching source instance: InvalidAMIID.NotFound: The image id 'ami-12345678' does not exist
```

**Cause:** AMI doesn't exist in your region.

**Solution:**
```hcl
# Use data source to get latest AMI
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "web" {
  ami = data.aws_ami.amazon_linux_2.id
  # ...
}
```

---

### Error: "A conflicting operation is currently in progress"

**Problem:**
```
Error: error waiting for Lambda Function to be created: timeout while waiting for state
```

**Cause:** AWS resource is still being created/modified.

**Solution:**
```bash
# Wait a few minutes and retry
terraform apply

# Or increase timeout
resource "aws_lambda_function" "example" {
  # ...

  timeouts {
    create = "10m"
    update = "10m"
  }
}
```

---

## State Issues

### Problem: State is out of sync

**Symptoms:**
- Terraform wants to recreate resources that already exist
- Resources exist in AWS but not in state

**Diagnosis:**
```bash
# Check what's in state
terraform state list

# Check details
terraform state show aws_instance.web

# Refresh state from AWS
terraform refresh
```

**Solution 1: Import existing resource**
```bash
# Import existing EC2 instance
terraform import aws_instance.web i-1234567890abcdef0

# Import S3 bucket
terraform import aws_s3_bucket.data my-bucket-name
```

**Solution 2: Remove from state (if resource was deleted manually)**
```bash
# Remove from state (doesn't delete in AWS)
terraform state rm aws_instance.old_server
```

---

### Problem: Corrupted state file

**Symptoms:**
```
Error: Failed to load state: state snapshot was created by Terraform v1.2.0, which is newer than current v1.1.0
```

**Solution:**
```bash
# 1. Backup state
cp terraform.tfstate terraform.tfstate.backup.$(date +%Y%m%d)

# 2. Upgrade Terraform
brew upgrade terraform  # or your package manager

# 3. If using remote state, check S3 versioning
aws s3api list-object-versions --bucket my-terraform-state --prefix terraform.tfstate

# 4. Restore previous version if needed
aws s3api get-object \
  --bucket my-terraform-state \
  --key terraform.tfstate \
  --version-id <VERSION_ID> \
  terraform.tfstate
```

---

### Problem: Multiple people modified infrastructure

**Symptoms:**
- State conflicts
- Resources exist but Terraform doesn't know about them

**Solution:**
```bash
# Pull latest state
terraform refresh

# If using remote state, check for conflicts
terraform state pull > current-state.json

# Manually merge or reconcile
# Then push
terraform state push merged-state.json
```

---

## Provider Issues

### Error: "Failed to query available provider packages"

**Problem:**
```
Error: Failed to query available provider packages

Could not retrieve the list of available versions for provider hashicorp/aws
```

**Solution:**
```bash
# Clear provider cache
rm -rf .terraform/
rm .terraform.lock.hcl

# Re-initialize
terraform init

# If behind proxy, set environment variables
export HTTP_PROXY=http://proxy.example.com:8080
export HTTPS_PROXY=http://proxy.example.com:8080
terraform init
```

---

### Error: "Provider version constraint"

**Problem:**
```
Error: Inconsistent dependency lock file

The provider version constraint could not be satisfied
```

**Solution:**
```bash
# Update lock file
terraform init -upgrade

# Or specify exact version
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "= 5.0.0"  # Pin to specific version
    }
  }
}
```

---

## Resource Errors

### Error: "Cycle" in dependency graph

**Problem:**
```
Error: Cycle: aws_security_group.web, aws_security_group.db
```

**Cause:** Circular dependency between resources.

**Solution:**
```hcl
# BAD - Circular reference
resource "aws_security_group" "web" {
  ingress {
    security_groups = [aws_security_group.db.id]
  }
}

resource "aws_security_group" "db" {
  ingress {
    security_groups = [aws_security_group.web.id]
  }
}

# GOOD - Use separate rules
resource "aws_security_group" "web" {
  name = "web-sg"
}

resource "aws_security_group" "db" {
  name = "db-sg"
}

resource "aws_security_group_rule" "web_to_db" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.web.id
  security_group_id        = aws_security_group.db.id
}
```

---

### Error: "InvalidParameterValue"

**Problem:**
```
Error: Error creating VPC: InvalidParameterValue: CIDR block 10.0.0.0/8 is too large
```

**Cause:** Invalid configuration values.

**Solution:**
```hcl
# Check AWS documentation for valid values
# For VPC, CIDR block must be /16 to /28

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"  # Valid
  # not "10.0.0.0/8"           # Too large
}
```

---

### Error: "Timeout"

**Problem:**
```
Error: error waiting for EC2 Instance to become ready: timeout while waiting for state
```

**Solution:**
```hcl
resource "aws_instance" "web" {
  # ...

  timeouts {
    create = "30m"
    update = "20m"
    delete = "20m"
  }
}
```

---

## Debugging Techniques

### Enable Detailed Logging

```bash
# Set log level
export TF_LOG=DEBUG
export TF_LOG_PATH=terraform.log

# Run command
terraform apply

# Check log
tail -f terraform.log

# Levels: TRACE, DEBUG, INFO, WARN, ERROR
```

---

### Use terraform console

```bash
# Interactive console to test expressions
terraform console

# Try expressions
> var.region
"us-east-1"

> aws_vpc.main.id
"vpc-1234567890"

> length(aws_subnet.public)
2

# Exit with Ctrl+D
```

---

### Preview Changes Without Applying

```bash
# Detailed plan
terraform plan

# Save plan to file
terraform plan -out=tfplan

# Show saved plan
terraform show tfplan

# Apply saved plan
terraform apply tfplan
```

---

### Use terraform graph

```bash
# Generate dependency graph
terraform graph > graph.dot

# Convert to image (requires graphviz)
sudo apt install graphviz
dot -Tpng graph.dot > graph.png

# Open image
xdg-open graph.png
```

---

### Validate Configuration

```bash
# Check syntax
terraform validate

# Format code
terraform fmt -check

# Show current state
terraform show

# List resources
terraform state list

# Show specific resource
terraform state show aws_instance.web
```

---

## Recovery Procedures

### Procedure 1: Recover from Manual Changes

**Scenario:** Someone modified AWS resources outside of Terraform.

```bash
# 1. See what Terraform thinks should change
terraform plan

# 2. If changes are acceptable, update state to match reality
terraform refresh
terraform apply

# 3. If you want to revert manual changes
terraform apply  # This will revert to what's in code
```

---

### Procedure 2: Recover from Accidental Deletion

**Scenario:** Accidentally deleted a resource from state.

```bash
# 1. Check what's missing
terraform plan
# Shows resource will be created

# 2. Import the existing resource
terraform import aws_instance.web i-1234567890

# 3. Verify
terraform plan
# Should show no changes
```

---

### Procedure 3: Rollback Bad Changes

**Scenario:** Applied changes that broke something.

```bash
# 1. If using S3 backend with versioning
aws s3api list-object-versions \
  --bucket my-terraform-state \
  --prefix terraform.tfstate

# 2. Download previous version
aws s3api get-object \
  --bucket my-terraform-state \
  --key terraform.tfstate \
  --version-id <PREVIOUS_VERSION_ID> \
  old-state.tfstate

# 3. Restore
terraform state push old-state.tfstate

# 4. Apply old configuration
git checkout <previous-commit>
terraform apply
```

---

### Procedure 4: Split State File

**Scenario:** State file too large, want to separate concerns.

```bash
# 1. Remove resources from current state
terraform state rm aws_instance.old_app

# 2. Create new directory
mkdir ../old-app
cd ../old-app

# 3. Create configuration
cat > main.tf << 'EOF'
resource "aws_instance" "old_app" {
  # ... configuration ...
}
EOF

# 4. Import into new state
terraform init
terraform import aws_instance.old_app i-0987654321
```

---

### Procedure 5: Disaster Recovery

**Scenario:** Everything is broken, state is lost.

```bash
# 1. Create new state file
mv terraform.tfstate terraform.tfstate.corrupted

# 2. Initialize new state
terraform init

# 3. Import ALL existing resources
# List all resources in AWS
aws ec2 describe-instances --query 'Reservations[].Instances[].[InstanceId,Tags[?Key==`Name`].Value|[0]]' --output table

# Import each one
terraform import aws_instance.web i-1234567890
terraform import aws_instance.db i-0987654321
# ... etc for all resources

# 4. Verify
terraform plan
# Should show minimal changes

# 5. Apply to sync
terraform apply
```

---

## Quick Reference

### Common Commands

```bash
# Initialize
terraform init

# Validate
terraform validate
terraform fmt

# Plan
terraform plan
terraform plan -out=tfplan

# Apply
terraform apply
terraform apply tfplan
terraform apply -auto-approve

# Destroy
terraform destroy
terraform destroy -target=aws_instance.web

# State
terraform state list
terraform state show <resource>
terraform state rm <resource>
terraform state mv <source> <destination>

# Import
terraform import <resource> <id>

# Output
terraform output
terraform output <name>

# Workspace
terraform workspace list
terraform workspace new <name>
terraform workspace select <name>

# Debugging
export TF_LOG=DEBUG
export TF_LOG_PATH=terraform.log
```

---

### Emergency Contacts

When you're stuck:

1. **Check Terraform docs**: https://registry.terraform.io/providers/hashicorp/aws/latest/docs
2. **Search GitHub issues**: https://github.com/hashicorp/terraform/issues
3. **HashiCorp Forum**: https://discuss.hashicorp.com/c/terraform-core
4. **Stack Overflow**: Tag `terraform` + `amazon-web-services`

---

Remember: **Always backup your state file before making changes!**

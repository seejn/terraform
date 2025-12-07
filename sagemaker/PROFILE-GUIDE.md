# AWS Profile Configuration Guide for Terraform

## Quick Start - 3 Ways to Use Profiles

### Method 1: Edit the Default in Code (Easiest)

Edit `sagemaker-with-profile.tf`:

```hcl
variable "aws_profile" {
  description = "AWS profile to use for authentication"
  type        = string
  default     = "my-sagemaker-profile"  # ← Change "default" to YOUR profile name
}
```

Then just run:
```bash
terraform init
terraform apply
```

---

### Method 2: Command Line (Quick Testing)

```bash
# Don't edit the file, pass profile via command line
terraform apply -var="aws_profile=my-dev-profile"

# With region too
terraform apply \
  -var="aws_profile=my-dev-profile" \
  -var="aws_region=us-west-2"
```

---

### Method 3: Config File (Best for Teams)

Create `terraform.tfvars`:
```bash
cat > terraform.tfvars << 'EOF'
aws_profile = "my-sagemaker-profile"
aws_region  = "us-east-1"
EOF

# Now just run
terraform apply
```

---

## Check Your Available Profiles

```bash
# List all configured profiles
aws configure list-profiles

# Example output:
# default
# dev-account
# prod-account
# sagemaker-profile
```

---

## Create a New Profile (If Needed)

```bash
# Interactive setup
aws configure --profile my-sagemaker-profile

# It will ask:
# AWS Access Key ID [None]: AKIAIOSFODNN7EXAMPLE
# AWS Secret Access Key [None]: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
# Default region name [None]: us-east-1
# Default output format [None]: json
```

**Or edit manually:**
```bash
# Edit credentials file
nano ~/.aws/credentials

# Add new profile:
[my-sagemaker-profile]
aws_access_key_id = AKIAIOSFODNN7EXAMPLE
aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY

# Edit config file
nano ~/.aws/config

# Add region:
[profile my-sagemaker-profile]
region = us-east-1
output = json
```

---

## Verify Profile Works

```bash
# Test the profile
aws sts get-caller-identity --profile my-sagemaker-profile

# Should show your account info:
# {
#     "UserId": "AIDACKCEVSQ6C2EXAMPLE",
#     "Account": "123456789012",
#     "Arn": "arn:aws:iam::123456789012:user/your-username"
# }
```

---

## Complete Examples

### Example 1: Use Dev Profile

```bash
cd /home/anon/Documents/code/terraform

# Option A: Edit the file
nano sagemaker-with-profile.tf
# Change: default = "dev-account"

# Option B: Use command line
terraform apply -var="aws_profile=dev-account"

# Option C: Create dev.tfvars
cat > dev.tfvars << 'EOF'
aws_profile = "dev-account"
aws_region  = "us-east-1"
EOF

terraform apply -var-file="dev.tfvars"
```

### Example 2: Multiple Environments

Create separate variable files:

```bash
# dev.tfvars
cat > dev.tfvars << 'EOF'
aws_profile = "dev-account"
aws_region  = "us-east-1"
EOF

# prod.tfvars
cat > prod.tfvars << 'EOF'
aws_profile = "prod-account"
aws_region  = "us-west-2"
EOF

# staging.tfvars
cat > staging.tfvars << 'EOF'
aws_profile = "staging-account"
aws_region  = "us-east-1"
EOF

# Deploy to dev
terraform apply -var-file="dev.tfvars"

# Deploy to prod
terraform apply -var-file="prod.tfvars"
```

### Example 3: Using Environment Variable

```bash
# Set profile for entire session
export AWS_PROFILE=my-sagemaker-profile

# Verify it's set
echo $AWS_PROFILE

# Now all terraform commands use this profile
terraform init
terraform plan
terraform apply

# Unset when done
unset AWS_PROFILE
```

---

## Multi-Account Setup (Advanced)

If you need resources in DIFFERENT AWS accounts:

```hcl
# provider.tf

# Primary account (dev)
provider "aws" {
  region  = "us-east-1"
  profile = "dev-account"
}

# Secondary account (prod) - with alias
provider "aws" {
  alias   = "production"
  region  = "us-east-1"
  profile = "prod-account"
}

# Data account - with alias
provider "aws" {
  alias   = "data"
  region  = "us-west-2"
  profile = "data-account"
}

# Resources in dev account (default provider)
resource "aws_sagemaker_notebook_instance" "dev_notebook" {
  name          = "dev-notebook"
  instance_type = "ml.t3.medium"
  role_arn      = aws_iam_role.dev_role.arn
}

# Resources in prod account (specify provider)
resource "aws_sagemaker_notebook_instance" "prod_notebook" {
  provider      = aws.production
  name          = "prod-notebook"
  instance_type = "ml.m5.xlarge"
  role_arn      = aws_iam_role.prod_role.arn
}

# Resources in data account
resource "aws_s3_bucket" "data_lake" {
  provider = aws.data
  bucket   = "company-data-lake"
}
```

---

## Troubleshooting

### Error: "No valid credential sources found"

```bash
# Check if profile exists
aws configure list-profiles

# Check if credentials are valid
aws sts get-caller-identity --profile my-sagemaker-profile

# If fails, reconfigure:
aws configure --profile my-sagemaker-profile
```

### Error: "Profile not found"

```bash
# List what profiles exist
cat ~/.aws/credentials | grep "^\["

# Output shows profiles like:
# [default]
# [dev-account]
# [prod-account]

# Make sure you're using the exact name
terraform apply -var="aws_profile=dev-account"  # Correct
terraform apply -var="aws_profile=dev"          # Wrong if profile is "dev-account"
```

### Error: "Access Denied"

Profile exists but lacks permissions:

```bash
# Check what identity is being used
aws sts get-caller-identity --profile my-sagemaker-profile

# Check IAM permissions in AWS Console:
# 1. Go to IAM → Users
# 2. Find your user
# 3. Check attached policies

# You need at minimum:
# - SageMakerFullAccess
# - AmazonS3FullAccess (or specific bucket access)
# - IAMFullAccess (to create roles)
```

---

## Best Practices

### 1. Use Variables for Flexibility

```hcl
# Good - easy to change
variable "aws_profile" {
  type = string
}

provider "aws" {
  profile = var.aws_profile
}

# Bad - hardcoded
provider "aws" {
  profile = "my-dev-account"
}
```

### 2. Document Required Profiles

Create a README:
```markdown
# Required AWS Profiles

This project requires the following AWS profile to be configured:

Profile name: `sagemaker-dev`
Permissions needed:
- AmazonSageMakerFullAccess
- AmazonS3FullAccess
- IAMFullAccess

Setup:
\`\`\`bash
aws configure --profile sagemaker-dev
\`\`\`
```

### 3. Use .gitignore for Variable Files

```bash
# .gitignore
*.tfvars
!example.tfvars

# This prevents committing sensitive profile names
```

### 4. Separate Environments Clearly

```bash
# Directory structure
terraform/
├── environments/
│   ├── dev/
│   │   ├── main.tf
│   │   └── terraform.tfvars  # aws_profile = "dev-account"
│   ├── staging/
│   │   ├── main.tf
│   │   └── terraform.tfvars  # aws_profile = "staging-account"
│   └── prod/
│       ├── main.tf
│       └── terraform.tfvars  # aws_profile = "prod-account"
└── modules/
    └── sagemaker/
        └── main.tf
```

---

## Quick Reference

```bash
# Method 1: Edit code default value
# In .tf file: default = "my-profile"

# Method 2: Command line
terraform apply -var="aws_profile=my-profile"

# Method 3: Environment variable
export AWS_PROFILE=my-profile
terraform apply

# Method 4: Variable file
echo 'aws_profile = "my-profile"' > terraform.tfvars
terraform apply

# Method 5: Specific variable file
terraform apply -var-file="dev.tfvars"

# Check which profile is active
terraform console
> var.aws_profile

# Verify credentials
aws sts get-caller-identity --profile my-profile
```

---

## Complete Working Example

```bash
# 1. List your profiles
aws configure list-profiles

# 2. Choose one (e.g., "dev-sagemaker")

# 3. Create terraform.tfvars
cat > terraform.tfvars << 'EOF'
aws_profile = "dev-sagemaker"
aws_region  = "us-east-1"
EOF

# 4. Initialize and apply
terraform init
terraform plan
terraform apply

# 5. Verify which profile was used
terraform output profile_used
```

---

## Summary

**Simplest way (recommended for beginners):**
1. Edit `sagemaker-with-profile.tf`
2. Change `default = "default"` to `default = "your-profile-name"`
3. Run `terraform apply`

**Most flexible way (recommended for teams):**
1. Keep code as-is
2. Create `terraform.tfvars` with your profile name
3. Add `*.tfvars` to `.gitignore`
4. Each team member uses their own profile

Choose the method that fits your workflow!

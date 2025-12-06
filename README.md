# Terraform AWS Infrastructure

This project manages AWS infrastructure including VPC, EC2, Lambda, and SageMaker resources.

## Prerequisites

1. **Install Terraform**: https://developer.hashicorp.com/terraform/install
2. **AWS CLI configured**: `aws configure` with your credentials
3. **IAM permissions**: Ensure your AWS user has permissions for VPC, EC2, Lambda, SageMaker, IAM

## Getting Started

### 1. Initialize Terraform
```bash
terraform init
```
This downloads the AWS provider and sets up the project.

### 2. Review the Plan
```bash
terraform plan
```
Shows what resources will be created without making changes.

### 3. Deploy Infrastructure
```bash
terraform apply
```
Type `yes` to confirm and deploy resources.

### 4. View Outputs
```bash
terraform output
```
Shows useful information like VPC ID, EC2 IP, etc.

### 5. Destroy Infrastructure
```bash
terraform destroy
```
Type `yes` to remove all managed resources.

## File Structure

- `main.tf` - Main resource definitions
- `variables.tf` - Input variables for customization
- `outputs.tf` - Output values after deployment
- `.gitignore` - Files to exclude from git

## Key Concepts

### Resources
Resources are the infrastructure components you create (VPC, EC2, Lambda, etc.)

### State File
Terraform stores the current state in `terraform.tfstate`. **Never edit manually!**

### Variables
Customize deployments without changing code. Use `-var` flag or `.tfvars` files:
```bash
terraform apply -var="aws_region=us-west-2"
```

### Dependencies
Terraform automatically handles resource dependencies. Example:
- EC2 instance needs the subnet
- Subnet needs the VPC
- Terraform creates them in correct order

## Next Steps

1. Modify `variables.tf` to customize region/AMI for your needs
2. Create a Lambda deployment package (lambda_function.zip)
3. Add security groups for EC2 access
4. Explore Terraform modules for reusable components
5. Set up remote state storage (S3 + DynamoDB)

## Common Commands

```bash
terraform fmt          # Format code
terraform validate     # Validate syntax
terraform show         # Show current state
terraform state list   # List managed resources
```

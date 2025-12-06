#!/bin/bash

# ============================================================================
# Vue.js Deployment Script for S3 + CloudFront
# ============================================================================
# This script automates the deployment of a Vue.js app to AWS S3 with CloudFront
#
# Usage:
#   ./deploy-vuejs.sh /path/to/your/vuejs/project
#
# Prerequisites:
#   - AWS CLI configured (aws configure)
#   - Terraform installed
#   - Vue.js project with npm build script
# ============================================================================

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Check if Vue.js project path is provided
if [ -z "$1" ]; then
    print_error "Usage: $0 /path/to/your/vuejs/project"
    exit 1
fi

VUEJS_PROJECT_PATH="$1"
TERRAFORM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

print_info "Starting Vue.js deployment process..."
echo ""

# ============================================================================
# Step 1: Verify Prerequisites
# ============================================================================

print_info "Checking prerequisites..."

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed. Install it from: https://aws.amazon.com/cli/"
    exit 1
fi
print_success "AWS CLI found"

# Check Terraform
if ! command -v terraform &> /dev/null; then
    print_error "Terraform is not installed. Install it from: https://www.terraform.io/downloads"
    exit 1
fi
print_success "Terraform found"

# Check if AWS is configured
if ! aws sts get-caller-identity &> /dev/null; then
    print_error "AWS CLI is not configured. Run: aws configure"
    exit 1
fi
print_success "AWS credentials configured"

# Check if Vue.js project exists
if [ ! -d "$VUEJS_PROJECT_PATH" ]; then
    print_error "Vue.js project not found at: $VUEJS_PROJECT_PATH"
    exit 1
fi
print_success "Vue.js project found"

# Check if package.json exists
if [ ! -f "$VUEJS_PROJECT_PATH/package.json" ]; then
    print_error "package.json not found in: $VUEJS_PROJECT_PATH"
    exit 1
fi
print_success "package.json found"

echo ""

# ============================================================================
# Step 2: Build Vue.js Application
# ============================================================================

print_info "Building Vue.js application..."
cd "$VUEJS_PROJECT_PATH"

# Install dependencies if node_modules doesn't exist
if [ ! -d "node_modules" ]; then
    print_warning "node_modules not found. Installing dependencies..."
    npm install
fi

# Build the project
npm run build

if [ ! -d "dist" ]; then
    print_error "Build failed - dist folder not created"
    exit 1
fi

print_success "Vue.js application built successfully"
echo ""

# ============================================================================
# Step 3: Initialize Terraform
# ============================================================================

print_info "Initializing Terraform..."
cd "$TERRAFORM_DIR"

# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
    print_warning "terraform.tfvars not found. Copying from example..."
    if [ -f "terraform.tfvars.example" ]; then
        cp terraform.tfvars.example terraform.tfvars
        print_warning "Please edit terraform.tfvars with your project details"
        read -p "Press Enter to continue after editing terraform.tfvars..."
    fi
fi

terraform init -upgrade

print_success "Terraform initialized"
echo ""

# ============================================================================
# Step 4: Deploy Infrastructure
# ============================================================================

print_info "Planning Terraform deployment..."
terraform plan -out=tfplan

echo ""
print_warning "Review the plan above. This will create AWS resources that may incur costs."
read -p "Do you want to apply this plan? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    print_info "Deployment cancelled"
    rm -f tfplan
    exit 0
fi

print_info "Deploying infrastructure..."
terraform apply tfplan
rm -f tfplan

print_success "Infrastructure deployed successfully"
echo ""

# ============================================================================
# Step 5: Upload Files to S3
# ============================================================================

# Get S3 bucket name from Terraform output
BUCKET_NAME=$(terraform output -raw s3_bucket_name)
CLOUDFRONT_DIST_ID=$(terraform output -raw cloudfront_distribution_id)
WEBSITE_URL=$(terraform output -raw website_url)

print_info "Uploading Vue.js build to S3 bucket: $BUCKET_NAME"

# Sync dist folder to S3
aws s3 sync "$VUEJS_PROJECT_PATH/dist" "s3://$BUCKET_NAME" --delete

print_success "Files uploaded to S3"
echo ""

# ============================================================================
# Step 6: Optimize Cache Headers (Optional)
# ============================================================================

print_info "Setting cache-control headers for optimal performance..."

# Cache static assets for 1 year
if [ -d "$VUEJS_PROJECT_PATH/dist/assets" ]; then
    aws s3 sync "$VUEJS_PROJECT_PATH/dist/assets" "s3://$BUCKET_NAME/assets" \
        --cache-control "public,max-age=31536000,immutable" \
        --metadata-directive REPLACE
    print_success "Cache headers set for /assets/*"
fi

# Cache HTML with short TTL
aws s3 cp "$VUEJS_PROJECT_PATH/dist/index.html" "s3://$BUCKET_NAME/index.html" \
    --cache-control "public,max-age=0,must-revalidate" \
    --metadata-directive REPLACE
print_success "Cache headers set for index.html"

echo ""

# ============================================================================
# Step 7: Invalidate CloudFront Cache
# ============================================================================

print_info "Invalidating CloudFront cache..."

INVALIDATION_ID=$(aws cloudfront create-invalidation \
    --distribution-id "$CLOUDFRONT_DIST_ID" \
    --paths "/*" \
    --query 'Invalidation.Id' \
    --output text)

print_success "CloudFront invalidation created: $INVALIDATION_ID"
echo ""

# ============================================================================
# Summary
# ============================================================================

echo ""
echo "============================================================================"
print_success "Deployment Complete!"
echo "============================================================================"
echo ""
echo "📦 S3 Bucket:            $BUCKET_NAME"
echo "🌐 CloudFront Distribution: $CLOUDFRONT_DIST_ID"
echo "🔗 Website URL:          $WEBSITE_URL"
echo ""
echo "Your Vue.js application is now live!"
echo ""
echo "Next Steps:"
echo "  1. Visit $WEBSITE_URL to view your site"
echo "  2. Test all routes to ensure Vue Router is working"
echo "  3. (Optional) Configure custom domain in terraform.tfvars"
echo ""
echo "To update your site in the future:"
echo "  1. Make changes to your Vue.js app"
echo "  2. Run: ./deploy-vuejs.sh $VUEJS_PROJECT_PATH"
echo ""
echo "To destroy all resources:"
echo "  1. cd $TERRAFORM_DIR"
echo "  2. aws s3 rm s3://$BUCKET_NAME --recursive"
echo "  3. terraform destroy"
echo ""
echo "============================================================================"

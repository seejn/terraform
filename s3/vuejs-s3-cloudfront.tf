# ============================================================================
# Vue.js Static Website Hosting on S3 with CloudFront CDN
# ============================================================================
# This Terraform configuration deploys a Vue.js application to AWS S3
# with CloudFront for global content delivery and caching
# ============================================================================

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Variables for customization
variable "project_name" {
  description = "Name of your Vue.js project"
  type        = string
  default     = "my-vuejs-app"
}

variable "domain_name" {
  description = "Custom domain name (optional, leave empty for CloudFront domain)"
  type        = string
  default     = ""
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "prod"
}

# ============================================================================
# STEP 1: S3 Bucket for Static Website Hosting
# ============================================================================
# This bucket will store all your Vue.js build files (HTML, CSS, JS, assets)

resource "aws_s3_bucket" "website" {
  bucket = "${var.project_name}-${var.environment}-website"

  tags = {
    Name        = "${var.project_name} Website"
    Environment = var.environment
    Purpose     = "Vue.js Static Website Hosting"
  }
}

# Block all public access - CloudFront will access via OAI
resource "aws_s3_bucket_public_access_block" "website" {
  bucket = aws_s3_bucket.website.id

  block_public_acls       = true
  block_public_policy     = false  # We need this false for CloudFront access
  ignore_public_acls      = true
  restrict_public_buckets = false
}

# Enable versioning for rollback capability
resource "aws_s3_bucket_versioning" "website" {
  bucket = aws_s3_bucket.website.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Server-side encryption for security
resource "aws_s3_bucket_server_side_encryption_configuration" "website" {
  bucket = aws_s3_bucket.website.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ============================================================================
# STEP 2: CloudFront Origin Access Identity (OAI)
# ============================================================================
# This allows CloudFront to access S3 bucket privately without making it public

resource "aws_cloudfront_origin_access_identity" "website" {
  comment = "OAI for ${var.project_name} website"
}

# ============================================================================
# STEP 3: S3 Bucket Policy for CloudFront Access
# ============================================================================
# Grants CloudFront OAI permission to read from S3 bucket

resource "aws_s3_bucket_policy" "website" {
  bucket = aws_s3_bucket.website.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontOAI"
        Effect = "Allow"
        Principal = {
          AWS = aws_cloudfront_origin_access_identity.website.iam_arn
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.website.arn}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.website]
}

# ============================================================================
# STEP 4: CloudFront Distribution for CDN and Caching
# ============================================================================
# This distributes your Vue.js app globally with edge caching

resource "aws_cloudfront_distribution" "website" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${var.project_name} Vue.js Website Distribution"
  default_root_object = "index.html"
  price_class         = "PriceClass_100"  # Use PriceClass_All for global coverage

  # Origin: S3 bucket
  origin {
    domain_name = aws_s3_bucket.website.bucket_regional_domain_name
    origin_id   = "S3-${aws_s3_bucket.website.id}"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.website.cloudfront_access_identity_path
    }
  }

  # Default cache behavior
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.website.id}"

    # Forwarding settings
    forwarding_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    # Caching policy
    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600    # 1 hour
    max_ttl                = 86400   # 24 hours
    compress               = true    # Enable Gzip compression
  }

  # Cache behavior for static assets (longer cache time)
  ordered_cache_behavior {
    path_pattern     = "/assets/*"
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.website.id}"

    forwarding_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 86400   # 24 hours
    max_ttl                = 31536000 # 1 year
    compress               = true
  }

  # Cache behavior for CSS and JS files
  ordered_cache_behavior {
    path_pattern     = "*.{css,js}"
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.website.id}"

    forwarding_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 86400   # 24 hours
    max_ttl                = 31536000 # 1 year
    compress               = true
  }

  # CRITICAL: Custom error response for Vue Router (SPA)
  # This ensures all routes redirect to index.html for client-side routing
  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
  }

  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }

  # Restrictions
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # SSL Certificate
  viewer_certificate {
    cloudfront_default_certificate = true
    # For custom domain, use:
    # acm_certificate_arn      = aws_acm_certificate.cert.arn
    # ssl_support_method       = "sni-only"
    # minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = {
    Name        = "${var.project_name} CDN"
    Environment = var.environment
  }
}

# ============================================================================
# OUTPUTS
# ============================================================================

output "s3_bucket_name" {
  description = "Name of the S3 bucket hosting the website"
  value       = aws_s3_bucket.website.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.website.arn
}

output "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution"
  value       = aws_cloudfront_distribution.website.id
}

output "cloudfront_domain_name" {
  description = "Domain name of the CloudFront distribution"
  value       = aws_cloudfront_distribution.website.domain_name
}

output "website_url" {
  description = "URL to access your Vue.js website"
  value       = "https://${aws_cloudfront_distribution.website.domain_name}"
}

output "deployment_command" {
  description = "AWS CLI command to sync your Vue.js build to S3"
  value       = "aws s3 sync ./dist s3://${aws_s3_bucket.website.id} --delete"
}

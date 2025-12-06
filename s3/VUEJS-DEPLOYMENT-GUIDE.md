# Vue.js Deployment Guide: S3 + CloudFront

This guide walks you through deploying your Vue.js application to AWS S3 with CloudFront CDN for global caching and fast content delivery.

---

## Architecture Overview

```
Vue.js App → S3 Bucket (Private) → CloudFront CDN → Users Worldwide
```

**Key Components:**
- **S3 Bucket**: Stores your static files (HTML, CSS, JS, images)
- **CloudFront**: Global CDN that caches content at edge locations
- **Origin Access Identity (OAI)**: Allows CloudFront to access private S3 bucket
- **Custom Error Responses**: Handles Vue Router for single-page application routing

---

## Prerequisites

1. **AWS Account** with appropriate permissions
2. **AWS CLI** installed and configured
   ```bash
   aws configure
   ```
3. **Terraform** installed (v1.0+)
   ```bash
   terraform --version
   ```
4. **Vue.js project** ready to build
   ```bash
   npm run build  # Creates ./dist folder
   ```

---

## Step-by-Step Deployment Process

### Step 1: Prepare Your Vue.js Application

#### 1.1 Configure Vue Router for History Mode (if using)

Update `router/index.js`:
```javascript
const router = createRouter({
  history: createWebHistory(process.env.BASE_URL),
  routes: [...]
})
```

#### 1.2 Build Your Vue.js App
```bash
cd /path/to/your/vuejs/project
npm run build
```

This creates a `dist/` folder with all static files.

#### 1.3 Verify Build Output
```bash
ls -la dist/
# Should see: index.html, assets/, favicon.ico, etc.
```

---

### Step 2: Configure Terraform Variables (Optional)

Create `terraform.tfvars`:
```hcl
project_name = "my-awesome-app"
environment  = "prod"
```

Or use command-line variables:
```bash
terraform apply -var="project_name=my-app"
```

---

### Step 3: Initialize Terraform

Navigate to the Terraform configuration directory:
```bash
cd /home/anon/Documents/code/terraform/s3
terraform init
```

This downloads the AWS provider and prepares your workspace.

---

### Step 4: Review the Infrastructure Plan

```bash
terraform plan
```

Review what Terraform will create:
- ✅ S3 bucket with versioning and encryption
- ✅ CloudFront distribution with OAI
- ✅ Bucket policy allowing CloudFront access
- ✅ Custom error responses for SPA routing

---

### Step 5: Deploy Infrastructure

```bash
terraform apply
```

Type `yes` to confirm. This takes 5-10 minutes (CloudFront is slow to provision).

**Important Outputs:**
```
s3_bucket_name          = "my-vuejs-app-prod-website"
cloudfront_domain_name  = "d1234567890abc.cloudfront.net"
website_url            = "https://d1234567890abc.cloudfront.net"
deployment_command      = "aws s3 sync ./dist s3://my-vuejs-app-prod-website --delete"
```

---

### Step 6: Upload Your Vue.js Build to S3

#### Option A: Using AWS CLI (Recommended)
```bash
# From your Vue.js project root (where dist/ folder is)
aws s3 sync ./dist s3://YOUR-BUCKET-NAME --delete

# Example:
aws s3 sync ./dist s3://my-vuejs-app-prod-website --delete
```

#### Option B: Using AWS Console
1. Go to S3 in AWS Console
2. Open your bucket
3. Click "Upload"
4. Drag and drop all files from `dist/` folder

**Important Flags:**
- `--delete`: Removes old files from S3 that are no longer in dist/
- `sync`: Only uploads changed files (faster than cp)

---

### Step 7: Set Cache-Control Headers (Optional but Recommended)

For better caching performance:

```bash
# Cache static assets for 1 year
aws s3 sync ./dist/assets s3://YOUR-BUCKET-NAME/assets \
  --cache-control "public,max-age=31536000,immutable" \
  --metadata-directive REPLACE

# Cache HTML with shorter TTL
aws s3 cp ./dist/index.html s3://YOUR-BUCKET-NAME/index.html \
  --cache-control "public,max-age=0,must-revalidate" \
  --metadata-directive REPLACE
```

---

### Step 8: Test Your Website

1. **Get CloudFront URL** from Terraform output:
   ```bash
   terraform output website_url
   ```

2. **Open in browser**:
   ```
   https://d1234567890abc.cloudfront.net
   ```

3. **Test Vue Router** (if applicable):
   - Navigate to different routes in your app
   - Refresh the page on a non-root route
   - Should NOT get 404 errors (thanks to custom error response)

---

## Understanding the Configuration

### S3 Bucket Settings

| Setting | Value | Purpose |
|---------|-------|---------|
| **Public Access** | Blocked | Security - only CloudFront can access |
| **Versioning** | Enabled | Rollback capability if needed |
| **Encryption** | AES256 | Data security at rest |

### CloudFront Cache Behavior

| Content Type | Default TTL | Max TTL | Purpose |
|--------------|-------------|---------|---------|
| HTML files | 1 hour | 24 hours | Allows updates to propagate |
| Static assets (/assets/*) | 24 hours | 1 year | Maximum performance |
| CSS/JS files | 24 hours | 1 year | Maximum performance |

### Custom Error Responses (Critical for SPAs)

| Error Code | Response | Purpose |
|------------|----------|---------|
| 403 | Return index.html (200) | Handle missing S3 objects |
| 404 | Return index.html (200) | Let Vue Router handle routing |

**Why this matters:** When users visit `/about`, S3 doesn't have an `about` file. Instead of showing 404, CloudFront serves `index.html`, and Vue Router takes over to show the correct route.

---

## Updating Your Website

After making changes to your Vue.js app:

1. **Rebuild the app:**
   ```bash
   npm run build
   ```

2. **Sync to S3:**
   ```bash
   aws s3 sync ./dist s3://YOUR-BUCKET-NAME --delete
   ```

3. **Invalidate CloudFront cache** (for immediate updates):
   ```bash
   aws cloudfront create-invalidation \
     --distribution-id YOUR-DISTRIBUTION-ID \
     --paths "/*"
   ```

   Get distribution ID:
   ```bash
   terraform output cloudfront_distribution_id
   ```

**Note:** CloudFront invalidations are free for first 1,000 paths/month, then $0.005 per path.

---

## Cost Estimation

### S3 Costs
- **Storage**: ~$0.023/GB/month
- **Data Transfer**: Free to CloudFront
- Example: 100 MB site = ~$0.002/month

### CloudFront Costs
- **Data Transfer**: $0.085/GB (first 10 TB to North America)
- **Requests**: $0.0075 per 10,000 HTTPS requests
- Example: 10,000 visitors, 5 MB avg = ~$4.25/month

**Total Estimate**: $5-10/month for small-medium traffic sites

---

## Custom Domain Setup (Optional)

To use your own domain (e.g., www.myapp.com):

### Step 1: Request SSL Certificate in ACM

**IMPORTANT**: Certificate must be in **us-east-1** region for CloudFront!

```bash
aws acm request-certificate \
  --domain-name myapp.com \
  --subject-alternative-names www.myapp.com \
  --validation-method DNS \
  --region us-east-1
```

### Step 2: Update Terraform Configuration

Add to `vuejs-s3-cloudfront.tf`:

```hcl
variable "domain_name" {
  default = "www.myapp.com"
}

resource "aws_cloudfront_distribution" "website" {
  # ... existing config ...

  aliases = [var.domain_name]

  viewer_certificate {
    acm_certificate_arn      = "arn:aws:acm:us-east-1:123456789:certificate/xxx"
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
    cloudfront_default_certificate = false
  }
}
```

### Step 3: Update DNS

Add CNAME record in your DNS provider:
```
Type: CNAME
Name: www
Value: d1234567890abc.cloudfront.net
```

---

## Troubleshooting

### Issue: 403 Forbidden Errors

**Cause**: S3 bucket policy or OAI misconfigured

**Solution:**
```bash
terraform destroy
terraform apply
```

### Issue: 404 on Refreshing Vue Routes

**Cause**: Missing custom error responses

**Solution:** Verify custom error responses in CloudFront settings

### Issue: Changes Not Showing Up

**Cause**: CloudFront cache

**Solution 1:** Wait for TTL to expire (default 1 hour)

**Solution 2:** Create cache invalidation
```bash
aws cloudfront create-invalidation \
  --distribution-id YOUR-DIST-ID \
  --paths "/*"
```

### Issue: Slow First Load

**Cause**: CloudFront warming up

**Solution:** Normal behavior. Subsequent loads will be fast.

---

## CI/CD Integration

### GitHub Actions Example

Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy to S3

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'

      - name: Install dependencies
        run: npm ci

      - name: Build
        run: npm run build

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1

      - name: Deploy to S3
        run: |
          aws s3 sync ./dist s3://${{ secrets.S3_BUCKET }} --delete

      - name: Invalidate CloudFront
        run: |
          aws cloudfront create-invalidation \
            --distribution-id ${{ secrets.CLOUDFRONT_DIST_ID }} \
            --paths "/*"
```

---

## Security Best Practices

1. **Never make S3 bucket public** - Use CloudFront OAI
2. **Enable HTTPS only** - `viewer_protocol_policy = "redirect-to-https"`
3. **Enable S3 versioning** - Easy rollback if needed
4. **Use least-privilege IAM** - Only grant necessary S3/CloudFront permissions
5. **Enable CloudFront logging** - Track access patterns
6. **Add WAF** (optional) - Protect against DDoS and attacks

---

## Performance Optimization Tips

1. **Use Vue.js code splitting**:
   ```javascript
   // router/index.js
   const About = () => import('./views/About.vue')
   ```

2. **Enable Gzip/Brotli compression** (already enabled in CloudFront config)

3. **Optimize images**:
   ```bash
   npm install --save-dev image-webpack-loader
   ```

4. **Use CDN for third-party libraries**

5. **Implement service workers** for offline support

---

## Cleanup (Delete Everything)

To destroy all infrastructure and avoid charges:

```bash
# First, empty the S3 bucket (versioned buckets require this)
aws s3 rm s3://YOUR-BUCKET-NAME --recursive

# Then destroy Terraform resources
terraform destroy
```

Type `yes` to confirm.

---

## Additional Resources

- [Vue.js Deployment Guide](https://cli.vuejs.org/guide/deployment.html)
- [CloudFront Documentation](https://docs.aws.amazon.com/cloudfront/)
- [S3 Static Website Hosting](https://docs.aws.amazon.com/AmazonS3/latest/userguide/WebsiteHosting.html)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

---

## Quick Reference Commands

```bash
# Build Vue.js app
npm run build

# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Deploy infrastructure
terraform apply

# Upload files to S3
aws s3 sync ./dist s3://BUCKET-NAME --delete

# Invalidate CloudFront cache
aws cloudfront create-invalidation --distribution-id DIST-ID --paths "/*"

# Get website URL
terraform output website_url

# Destroy everything
terraform destroy
```

---

## Summary

You now have a production-ready Vue.js deployment with:

- ✅ Secure S3 hosting (private bucket)
- ✅ Global CDN with CloudFront
- ✅ Automatic HTTPS
- ✅ Proper SPA routing support
- ✅ Optimized caching strategy
- ✅ Version control for rollbacks
- ✅ Infrastructure as Code with Terraform

Your website is now globally distributed, fast, secure, and scalable!

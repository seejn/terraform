# Vue.js S3 + CloudFront Deployment

Deploy your Vue.js application to AWS S3 with CloudFront CDN in minutes.

## Quick Start

### Automated Deployment (Recommended)

```bash
# 1. Configure your project name
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your project details

# 2. Run the deployment script
./deploy-vuejs.sh /path/to/your/vuejs/project
```

The script will:
- ✅ Build your Vue.js app
- ✅ Deploy AWS infrastructure (S3 + CloudFront)
- ✅ Upload your files
- ✅ Configure caching
- ✅ Provide your website URL

### Manual Deployment

```bash
# 1. Build your Vue.js app
cd /path/to/your/vuejs/project
npm run build

# 2. Deploy infrastructure
cd /home/anon/Documents/code/terraform/s3
terraform init
terraform apply

# 3. Upload files
aws s3 sync /path/to/your/vuejs/project/dist s3://YOUR-BUCKET-NAME --delete

# 4. Get website URL
terraform output website_url
```

## Files in This Directory

| File | Description |
|------|-------------|
| `vuejs-s3-cloudfront.tf` | Main Terraform configuration |
| `VUEJS-DEPLOYMENT-GUIDE.md` | Complete deployment guide |
| `deploy-vuejs.sh` | Automated deployment script |
| `terraform.tfvars.example` | Configuration template |

## What Gets Created

- **S3 Bucket**: Private bucket for hosting static files
- **CloudFront Distribution**: Global CDN for fast content delivery
- **Origin Access Identity**: Secure access from CloudFront to S3
- **Custom Error Responses**: Vue Router SPA support

## Architecture

```
┌─────────────┐     ┌──────────┐     ┌────────────────┐     ┌──────┐
│  Vue.js App │────▶│ S3 Bucket│◀────│CloudFront (CDN)│◀────│ User │
│   (Build)   │     │ (Private)│     │  (Edge Caching)│     └──────┘
└─────────────┘     └──────────┘     └────────────────┘
```

## Key Features

✅ **Security**: Private S3 bucket with CloudFront OAI
✅ **Performance**: Global CDN with optimized caching
✅ **SPA Support**: Custom error responses for Vue Router
✅ **HTTPS**: Automatic SSL/TLS encryption
✅ **Versioning**: Rollback capability
✅ **Cost-Effective**: ~$5-10/month for typical traffic

## Configuration

Edit `terraform.tfvars`:

```hcl
project_name = "my-awesome-app"  # Your project name
environment  = "prod"            # dev, staging, or prod
domain_name  = ""                # Optional: custom domain
```

## Updating Your Site

After making changes to your Vue.js app:

```bash
# Option 1: Use the script
./deploy-vuejs.sh /path/to/your/vuejs/project

# Option 2: Manual update
npm run build
aws s3 sync ./dist s3://YOUR-BUCKET-NAME --delete
aws cloudfront create-invalidation --distribution-id DIST-ID --paths "/*"
```

## Custom Domain Setup

1. Request ACM certificate in `us-east-1`:
   ```bash
   aws acm request-certificate \
     --domain-name myapp.com \
     --validation-method DNS \
     --region us-east-1
   ```

2. Update `terraform.tfvars`:
   ```hcl
   domain_name = "www.myapp.com"
   ```

3. Update DNS with CNAME to CloudFront domain

4. Re-deploy:
   ```bash
   terraform apply
   ```

See [VUEJS-DEPLOYMENT-GUIDE.md](./VUEJS-DEPLOYMENT-GUIDE.md#custom-domain-setup-optional) for details.

## Caching Strategy

| Content | Cache Duration | Why |
|---------|----------------|-----|
| `index.html` | 0s (always fresh) | Allows updates to propagate |
| `/assets/*` | 1 year | Hashed filenames = safe to cache |
| `*.css`, `*.js` | 1 year | Hashed filenames = safe to cache |

## Troubleshooting

### 404 on page refresh
**Solution**: Custom error responses are configured to serve `index.html` for 404s, enabling Vue Router.

### Changes not showing
**Solution**: Invalidate CloudFront cache:
```bash
aws cloudfront create-invalidation --distribution-id DIST-ID --paths "/*"
```

### 403 errors
**Solution**: Check S3 bucket policy and CloudFront OAI configuration:
```bash
terraform destroy
terraform apply
```

## Cost Estimation

**S3**:
- Storage: $0.023/GB/month
- Transfer to CloudFront: Free

**CloudFront**:
- Data transfer: $0.085/GB (first 10 TB)
- Requests: $0.0075 per 10,000

**Example**: 10,000 visitors/month, 5 MB average = ~$4.25/month

## Cleanup

To delete all resources:

```bash
# 1. Empty the S3 bucket
aws s3 rm s3://YOUR-BUCKET-NAME --recursive

# 2. Destroy infrastructure
terraform destroy
```

## Documentation

- [Complete Deployment Guide](./VUEJS-DEPLOYMENT-GUIDE.md) - Detailed walkthrough
- [Terraform Configuration](./vuejs-s3-cloudfront.tf) - Infrastructure code

## Support

For issues or questions:
1. Check [VUEJS-DEPLOYMENT-GUIDE.md](./VUEJS-DEPLOYMENT-GUIDE.md)
2. Review [Troubleshooting section](#troubleshooting)
3. Verify AWS credentials: `aws sts get-caller-identity`

## Requirements

- AWS Account with permissions for S3, CloudFront, IAM
- AWS CLI configured (`aws configure`)
- Terraform >= 1.0
- Node.js and npm
- Vue.js project with build script

---

**Ready to deploy?** Start with the [Quick Start](#quick-start) section above!

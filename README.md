# AWS Insecure Infrastructure Example

This project creates an AWS infrastructure that intentionally contains common security compliance issues for demonstration and learning purposes.

## ⚠️ WARNING ⚠️

**DO NOT** deploy this infrastructure in a production environment or with real credentials. This code intentionally creates resources with security vulnerabilities as a learning tool.

## Security Issues Demonstrated

1. **Insecure S3 Bucket Configurations**
   - Public access enabled
   - Missing encryption
   - Insecure bucket policies
   - Logging disabled
   - Versioning disabled

2. **Insufficient IAM Controls**
   - Over-privileged IAM users and roles
   - Long-lived access keys without rotation
   - Missing MFA enforcement
   - Overly permissive policies

3. **Unpatched EC2 Vulnerabilities**
   - Outdated AMI
   - Unencrypted EBS volumes
   - No patching strategy
   - Excessive permissions via instance profiles

4. **Network Security Weaknesses**
   - Overly permissive security groups
   - Public-facing resources
   - Missing network segmentation
   - No VPC flow logs

## Additional Security Issues

- Insecure RDS instance with hardcoded credentials and public access
- Insecure KMS key with overexposed policy
- Lambda function with hardcoded secrets in environment variables
- CloudTrail without log file validation or encryption
- ECR repository with mutable image tags

## Usage

```bash
# Initialize Terraform
terraform init

# Plan the deployment
terraform plan

# Apply the configuration (NOT RECOMMENDED)
# terraform apply
```

## Remediation

This repository can be used to learn how to detect and fix common AWS security issues. Each resource can be modified to follow security best practices.
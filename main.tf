provider "aws" {
  region = var.aws_region
  profile = "cloudgeni-iac"
}

resource "aws_s3_bucket" "data_bucket" {
  bucket = var.bucket_name
}

resource "aws_s3_bucket_public_access_block" "data_bucket_public_access" {
  bucket = aws_s3_bucket.data_bucket.id
  
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}


resource "aws_s3_bucket_policy" "allow_public_access" {
  bucket = aws_s3_bucket.data_bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
    {
      Sid       = "AllowSSLRequestsOnly"
      Action    = "s3:*"
      Effect    = "Deny"
      Resource  = [
      aws_s3_bucket.data_bucket.arn,
      "${aws_s3_bucket.data_bucket.arn}/*"
      ]
      Condition = {
        Bool = {
          "aws:SecureTransport" = false
        }
      }
      Principal = "*"
    },
    {
      Sid       = "AWSCloudTrailAclCheck"
      Effect    = "Allow"
      Principal = {
        Service = "cloudtrail.amazonaws.com"
      }
      Action    = "s3:GetBucketAcl"
      Resource  = aws_s3_bucket.data_bucket.arn
    },
    {
      Sid       = "AWSCloudTrailWrite"
      Effect    = "Allow"
      Principal = {
        Service = "cloudtrail.amazonaws.com"
      }
      Action    = "s3:PutObject"
      Resource  = "${aws_s3_bucket.data_bucket.arn}/AWSLogs/*"
      Condition = {
        StringEquals = {
          "s3:x-amz-acl" = "bucket-owner-full-control"
        }
      }
    }
    ]
  })
}


resource "aws_s3_bucket_versioning" "data_bucket_versioning" {
  bucket = aws_s3_bucket.data_bucket.id
  versioning_configuration {
    status = "Disabled"
  }
}

resource "aws_iam_user" "admin_user" {
  name = var.admin_username
}

resource "aws_iam_access_key" "admin_key" {
  user = aws_iam_user.admin_user.name
}

resource "aws_iam_user_policy" "admin_policy" {
  name = "admin-policy"
  user = aws_iam_user.admin_user.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "*"
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  
  tags = {
    Name = "insecure-vpc"
  }
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true  # All instances get public IPs automatically
  
  tags = {
    Name = "public-subnet-a"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr_b
  availability_zone       = "${var.aws_region}b" 
  map_public_ip_on_launch = true
  
  tags = {
    Name = "public-subnet-b"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  
  tags = {
    Name = "main-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  
  tags = {
    Name = "public-route-table"
  }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

# Overly permissive security group (allows all traffic)
resource "aws_security_group" "wide_open" {
  name        = "wide-open-sg"
  description = "Allow all inbound and outbound traffic"
  vpc_id      = aws_vpc.main.id
  
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all inbound traffic"
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }
  
  tags = {
    Name = "insecure-sg"
  }
}

resource "aws_instance" "web_server" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public_a.id
  vpc_security_group_ids = [aws_security_group.wide_open.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  
  # No encryption for the root volume
  root_block_device {
    volume_size = 8
    encrypted   = false
  }
  
  # No user data for patching/updates
  
  tags = {
    Name = "insecure-web-server"
  }
}

resource "aws_iam_role" "ec2_role" {
  name = "ec2-admin-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "ec2_admin_policy" {
  name = "ec2-admin-policy"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "*"
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-admin-profile"
  role = aws_iam_role.ec2_role.name
}

# Adding an insecure RDS instance with public accessibility
resource "aws_db_subnet_group" "default" {
  name       = "main"
  subnet_ids = [aws_subnet.public_a.id, aws_subnet.public_b.id]

  tags = {
    Name = "insecure-db-subnet-group"
  }
}

resource "aws_db_instance" "default" {
  allocated_storage      = 10
  engine                 = "mysql"
  engine_version         = "5.7"  # Older version
  instance_class         = "db.t3.micro"
  db_name                = "insecure_db"
  username               = "admin"
  password               = "password123"  # Hardcoded password (bad practice)
  parameter_group_name   = "default.mysql5.7"
  skip_final_snapshot    = true
  publicly_accessible    = true  # Publicly accessible (bad practice)
  db_subnet_group_name   = aws_db_subnet_group.default.name
  vpc_security_group_ids = [aws_security_group.wide_open.id]  # Using the wide open security group
  storage_encrypted      = false  # No encryption at rest
}

# Create an S3 VPC Endpoint but with a policy that allows all actions
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${var.aws_region}.s3"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = "*"
        Resource  = "*"
      }
    ]
  })
  
  tags = {
    Name = "s3-endpoint-insecure"
  }
}

# Create an insecure CloudTrail (not encrypted, no log validation)
resource "aws_cloudtrail" "insecure_trail" {
  name                          = "insecure-trail"
  s3_bucket_name                = aws_s3_bucket.data_bucket.id
  include_global_service_events = true
  is_multi_region_trail         = false
  enable_logging                = true
  enable_log_file_validation    = false # Log file validation disabled (bad practice)
  kms_key_id                    = null # No encryption (bad practice)
}

# Create an insecure KMS key with overexposed policy
resource "aws_kms_key" "insecure_key" {
  description             = "Insecure KMS key"
  deletion_window_in_days = 7
  enable_key_rotation     = false # Key rotation disabled (bad practice)
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "Enable IAM User Permissions"
        Effect    = "Allow"
        Principal = "*" # Allow any principal (bad practice)
        Action    = "kms:*"
        Resource  = "*"
      }
    ]
  })
}

# Create an insecure ECR repository with mutable image tags
resource "aws_ecr_repository" "insecure_repo" {
  name = "insecure-repo"
  
  image_tag_mutability = "MUTABLE" # Allows overwriting existing tags (bad practice)
  
  # Image scanning not configured
  
  # No encryption configuration specified
}

# Create an insecure Lambda function with excessive permissions
resource "aws_lambda_function" "insecure_lambda" {
  filename      = "dummy_lambda.zip"
  function_name = "insecure-lambda"
  role          = aws_iam_role.ec2_role.arn # Using the same overly permissive role
  handler       = "index.handler"
  runtime       = "nodejs18.x" # Updated to a supported runtime, but still shows insecure practices
  
  environment {
    variables = {
      API_KEY = "super_secret_key_12345" # Hardcoded secrets (bad practice)
      DB_PASSWORD = "password123"
    }
  }
  
  # No VPC configuration - Lambda is public
  
  # No dead letter queue configuration
} 
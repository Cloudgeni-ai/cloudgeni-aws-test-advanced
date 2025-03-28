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
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.data_bucket.arn}/*"
      },
      {
        Sid       = "AWSCloudTrailAclCheck"
        Effect    = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action    = "s3:GetBucketAcl"
        Resource  = "${aws_s3_bucket.data_bucket.arn}"
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


resource "aws_security_group" "nlp_chatbot" {
  name        = "nlp-chatbot-sg"
  description = "Security group for NLP Chatbot application"
  vpc_id      = aws_vpc.main.id
  
  # Allow SSH from specific IP
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["1.2.3.4/32"]  # Replace with your IP
    description = "SSH access from specific IP"
  }
  
  # Allow HTTPS from anywhere
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS access from anywhere"
  }
  
  # Allow custom TCP port 8501 from anywhere
  ingress {
    from_port   = 8501
    to_port     = 8501
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Custom TCP 8501 access from anywhere"
  }
  
  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }
  
  tags = {
    Name        = "nlp-chatbot-sg"
    Project     = "NLP-Chatbot"
    Environment = "Production"
    Department  = "AI-Research"
  }
}




resource "aws_launch_template" "lt_nlp_chatbot" {
  name = "lt-nlp-chatbot"
  description = "Launch Template for NLP Chatbot with GPU support"
  
  image_id = "ami-0123456789example"  # Deep Learning AMI w/ GPU
  instance_type = "g4dn.xlarge"
  
  network_interfaces {
    associate_public_ip_address = true
    security_groups = [aws_security_group.nlp_chatbot.id]
  }
  
  key_name = "ai-development-key"
  
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 200
      volume_type = "gp3"
      delete_on_termination = true
      encrypted = true
    }
  }
  
  user_data = base64encode(<<-EOF
  #!/bin/bash
  # Update system packages
  sudo yum update -y
  sudo yum groupinstall -y "Development Tools"
  
  # Install Python 3.12
  sudo yum install -y openssl-devel bzip2-devel libffi-devel
  wget https://www.python.org/ftp/python/3.12.0/Python-3.12.0.tgz
  tar xzf Python-3.12.0.tgz
  cd Python-3.12.0
  ./configure --enable-optimizations
  sudo make altinstall
  cd ..
  rm -rf Python-3.12.0*
  
  # Create virtual environment
  python3.12 -m venv /home/ec2-user/nlp_env
  source /home/ec2-user/nlp_env/bin/activate
  
  # Install Python packages
  pip install --upgrade pip
  pip install torch torchvision torchaudio
  pip install transformers
  pip install langchain
  pip install streamlit
  pip install boto3
  pip install "psycopg[binary,pool]"
  pip install pgvector
  
  # Install and configure PostgreSQL with pgvector
  sudo yum install -y postgresql postgresql-server postgresql-devel
  sudo postgresql-setup initdb
  sudo systemctl start postgresql
  sudo systemctl enable postgresql
  
  # Configure PostgreSQL
  sudo -u postgres psql -c "CREATE DATABASE semantic_search;"
  sudo -u postgres psql -c "CREATE EXTENSION vector;" -d semantic_search
  
  # Install CloudWatch agent
  sudo yum install -y amazon-cloudwatch-agent
  
  # Configure CloudWatch agent
  cat <<'EOT' > /opt/aws/amazon-cloudwatch-agent/bin/config.json
  {
    "agent": {
      "metrics_collection_interval": 60
    },
    "metrics": {
      "metrics_collected": {
        "cpu": {
          "measurement": [
          "cpu_usage_idle",
          "cpu_usage_iowait",
          "cpu_usage_user",
          "cpu_usage_system"
          ],
          "metrics_collection_interval": 60,
          "totalcpu": false
        },
        "mem": {
          "measurement": [
          "mem_used_percent",
          "mem_total",
          "mem_used",
          "mem_available"
          ],
          "metrics_collection_interval": 60
        }
      }
    }
  }
  EOT
  
  # Start CloudWatch agent
  sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:/opt/aws/amazon-cloudwatch-agent/bin/config.json
  sudo systemctl start amazon-cloudwatch-agent
  sudo systemctl enable amazon-cloudwatch-agent
  EOF
  )
  
  tags = {
    Name        = "NLP-Chatbot-Production"
    Project     = "NLP-Chatbot"
    Environment = "Production"
    Department  = "AI-Research"
  }
  
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "NLP-Chatbot-Production"
      Project     = "NLP-Chatbot"
      Environment = "Production"
      Department  = "AI-Research"
    }
  }
  
  tag_specifications {
    resource_type = "volume"
    tags = {
      Name        = "NLP-Chatbot-Production"
      Project     = "NLP-Chatbot"
      Environment = "Production"
      Department  = "AI-Research"
    }
  }
}



# Create security group for ALB
resource "aws_security_group" "nlp_chatbot_alb_sg" {
  name        = "nlp-chatbot-alb-sg"
  description = "Security group for NLP Chatbot ALB"
  vpc_id      = aws_vpc.main.id
  
  # Allow HTTP from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP access from anywhere"
  }
  
  # Allow HTTPS from anywhere
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS access from anywhere"
  }
  
  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }
  
  tags = {
    Name        = "NLP-Chatbot-ALB-SG"
    Project     = "NLP-Chatbot"
    Environment = "Production"
    Department  = "AI-Research"
  }
}

# Create Application Load Balancer
resource "aws_lb" "nlp_chatbot_alb" {
  name               = "nlp-chatbot-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.nlp_chatbot_alb_sg.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]
  
  enable_deletion_protection = false
  
  tags = {
    Name        = "NLP-Chatbot-ALB"
    Project     = "NLP-Chatbot"
    Environment = "Production"
    Department  = "AI-Research"
  }
}

# Create HTTP listener
resource "aws_lb_listener" "nlp_chatbot_http" {
  load_balancer_arn = aws_lb.nlp_chatbot_alb.arn
  port              = "80"
  protocol          = "HTTP"
  
  default_action {
    type = "fixed-response"
    
    fixed_response {
      content_type = "text/plain"
      message_body = "Please use HTTPS"
      status_code  = "200"
    }
  }
}

# Create HTTPS listener (commented out as SSL certificate ARN is not provided)
# Uncomment and provide certificate_arn when SSL certificate is available
/*
resource "aws_lb_listener" "nlp_chatbot_https" {
  load_balancer_arn = aws_lb.nlp_chatbot_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = "arn:aws:acm:region:account:certificate/certificate-id"
  
  default_action {
    type = "fixed-response"
    
    fixed_response {
      content_type = "text/plain"
      message_body = "Default HTTPS response"
      status_code  = "200"
    }
  }
}
*/

# Create target group for NLP Chatbot
resource "aws_lb_target_group" "nlp_chatbot_tg" {
  name        = "nlp-chatbot-tg"
  port        = 8501
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"
  
  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    path               = "/_stcore/health"
    port               = "traffic-port"
    protocol           = "HTTP"
    timeout            = 5
    unhealthy_threshold = 2
  }
  
  tags = {
    Name        = "NLP-Chatbot-TG"
    Project     = "NLP-Chatbot"
    Environment = "Production"
    Department  = "AI-Research"
  }
}

# Add rule to the HTTP listener to forward traffic to target group
resource "aws_lb_listener_rule" "nlp_chatbot_rule" {
  listener_arn = aws_lb_listener.nlp_chatbot_http.arn
  priority     = 1
  
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nlp_chatbot_tg.arn
  }
  
  condition {
    path_pattern {
      values = ["/*"]
    }
  }
}

# Create Auto Scaling Group
resource "aws_autoscaling_group" "nlp_chatbot_asg" {
  name                = "nlp-chatbot-asg"
  desired_capacity    = 1
  max_size           = 3
  min_size           = 1
  target_group_arns  = [aws_lb_target_group.nlp_chatbot_tg.arn]
  vpc_zone_identifier = [aws_subnet.public_a.id, aws_subnet.public_b.id]
  health_check_type  = "ELB"
  health_check_grace_period = 300
  
  launch_template {
    id      = aws_launch_template.lt_nlp_chatbot.id
    version = "$Latest"
  }
  
  enabled_metrics = [
  "GroupMinSize",
  "GroupMaxSize",
  "GroupDesiredCapacity",
  "GroupInServiceInstances",
  "GroupPendingInstances",
  "GroupStandbyInstances",
  "GroupTerminatingInstances",
  "GroupTotalInstances"
  ]
  
  tag {
    key                 = "Name"
    value               = "NLP-Chatbot-ASG"
    propagate_at_launch = true
  }
  
  tag {
    key                 = "Project"
    value               = "NLP-Chatbot"
    propagate_at_launch = true
  }
  
  tag {
    key                 = "Environment"
    value               = "Production"
    propagate_at_launch = true
  }
  
  tag {
    key                 = "Department"
    value               = "AI-Research"
    propagate_at_launch = true
  }
}

# Create IAM role for NLP Chatbot EC2 instances
resource "aws_iam_role" "nlp_chatbot_ec2_role" {
  name = "nlp_chatbot_ec2_role"
  
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

# Attach AmazonBedrockFullAccess managed policy
resource "aws_iam_role_policy_attachment" "bedrock_policy" {
  role       = aws_iam_role.nlp_chatbot_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonBedrockFullAccess"
}

# Attach AmazonComprehendFullAccess managed policy
resource "aws_iam_role_policy_attachment" "comprehend_policy" {
  role       = aws_iam_role.nlp_chatbot_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/ComprehendFullAccess"
}

# Create Instance Profile
resource "aws_iam_instance_profile" "nlp_chatbot_ec2_profile" {
  name = "nlp_chatbot_ec2_profile"
  role = aws_iam_role.nlp_chatbot_ec2_role.name
}

# SNS Topic for CloudWatch Alarms
resource "aws_sns_topic" "nlp_chatbot_alarms" {
  name = "nlp-chatbot-alarms"
  
  tags = {
    Name        = "NLP-Chatbot-Alarms"
    Project     = "NLP-Chatbot"
    Environment = "Production"
    Department  = "AI-Research"
  }
}

# Attach CloudWatch Agent policy to NLP Chatbot EC2 role
resource "aws_iam_role_policy_attachment" "cloudwatch_agent_policy" {
  role       = aws_iam_role.nlp_chatbot_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# CPU Utilization Alarm
resource "aws_cloudwatch_metric_alarm" "nlp_chatbot_high_cpu_alarm" {
  alarm_name          = "nlp_chatbot_high_cpu_alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 5
  metric_name        = "CPUUtilization"
  namespace          = "AWS/EC2"
  period             = 60
  statistic          = "Average"
  threshold          = 80
  alarm_description  = "CPU utilization has exceeded 80% for 5 minutes"
  alarm_actions      = [aws_sns_topic.nlp_chatbot_alarms.arn]
  
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.nlp_chatbot_asg.name
  }
  
  tags = {
    Name        = "NLP-Chatbot-CPU-Alarm"
    Project     = "NLP-Chatbot"
    Environment = "Production"
    Department  = "AI-Research"
  }
}

# Memory Usage Alarm
resource "aws_cloudwatch_metric_alarm" "nlp_chatbot_low_memory_alarm" {
  alarm_name          = "nlp_chatbot_low_memory_alarm"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 5
  metric_name        = "mem_available"
  namespace          = "CWAgent"
  period             = 60
  statistic          = "Average"
  threshold          = 1073741824  # 1GB in bytes
  alarm_description  = "Available memory is less than 1GB for 5 minutes"
  alarm_actions      = [aws_sns_topic.nlp_chatbot_alarms.arn]
  
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.nlp_chatbot_asg.name
  }
  
  tags = {
    Name        = "NLP-Chatbot-Memory-Alarm"
    Project     = "NLP-Chatbot"
    Environment = "Production"
    Department  = "AI-Research"
  }
}

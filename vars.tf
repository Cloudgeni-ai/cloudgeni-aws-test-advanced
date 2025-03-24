variable "aws_region" {
  description = "The AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "bucket_name" {
  description = "Name of the insecure S3 bucket"
  type        = string
  default     = "insecure-data-bucket-example"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet in AZ a"
  type        = string
  default     = "10.0.3.0/24"
}

variable "public_subnet_cidr_b" {
  description = "CIDR block for the public subnet in AZ b"
  type        = string
  default     = "10.0.2.0/24"
}

variable "admin_username" {
  description = "Username for the admin IAM user"
  type        = string
  default     = "admin-user"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "ami_id" {
  description = "AMI ID for the EC2 instance (outdated but available)"
  type        = string
  default     = "ami-0e9089763828757e1"
} 

variable "vpn_cidr_block" {
  description = "VPN CIDR block"
  type        = string
}

variable "db_identifier" {
  type        = string
  description = "Identifier for the database instance"
}

variable "db_instance_class" {
  type        = string
  description = "Instance class of the database"
}

variable "db_engine" {
  type        = string
  description = "Database engine type"
}

variable "db_engine_version" {
  type        = string
  description = "Engine version of the database"
}

variable "db_allocated_storage" {
  type        = number
  description = "Allocated storage size for the database, in GB"
}

variable "db_user" {
  type        = string
  description = "Username for the database"
}

variable "db_password" {
  type        = string
  sensitive   = true
  description = "Password for the database user"
}

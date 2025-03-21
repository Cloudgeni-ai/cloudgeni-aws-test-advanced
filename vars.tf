
variable "aws_region" {
  description = "The AWS region to deploy resources"
  type        = string
  default     = "eu-north-1"
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

variable "eks_cluster_name" {
  description = "The name of the EKS cluster"
  type        = string
  default     = "private-eks-cluster"
}

variable "eks_node_group_name" {
  description = "EKS Node Group Name"
  type        = string
  default     = "private-eks-node-group"
}

variable "eks_nodes_instance_type" {
  description = "EKS Node Group Instance Type"
  type        = string
  default     = "t3.medium"
}

variable "desired_capacity" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "max_capacity" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 5
}

variable "min_capacity" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1
}

variable "vpc_id" {
  description = "ID of the VPC in which to deploy the cluster"
  type        = string
}

variable "private_subnet_ids" {
  description = "IDs of the private subnets"
  type        = list(string)
}

variable "eks_version" {
  description = "Version of EKS"
  type        = string
  default     = "1.27"
}

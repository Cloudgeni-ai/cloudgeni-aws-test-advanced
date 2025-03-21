output "s3_bucket_name" {
  value       = aws_s3_bucket.data_bucket.bucket
  description = "The name of the insecure S3 bucket"
}

output "s3_bucket_arn" {
  value       = aws_s3_bucket.data_bucket.arn
  description = "The ARN of the insecure S3 bucket"
}

output "admin_user_name" {
  value       = aws_iam_user.admin_user.name
  description = "The name of the over-privileged IAM user"
}

output "admin_access_key_id" {
  value       = aws_iam_access_key.admin_key.id
  description = "The access key ID for the admin user"
  sensitive   = true
}

output "admin_secret_key" {
  value       = aws_iam_access_key.admin_key.secret
  description = "The secret access key for the admin user"
  sensitive   = true
}

output "vpc_id" {
  value       = aws_vpc.main.id
  description = "The ID of the VPC"
}

output "public_subnet_a_id" {
  value       = aws_subnet.public_a.id
  description = "The ID of the public subnet in AZ a"
}

output "public_subnet_b_id" {
  value       = aws_subnet.public_b.id
  description = "The ID of the public subnet in AZ b"
}



output "ec2_instance_id" {
  value       = aws_instance.web_server.id
  description = "The ID of the EC2 instance"
}

output "ec2_public_ip" {
  value       = aws_instance.web_server.public_ip
  description = "The public IP of the EC2 instance"
} 

# Security group for private web server
resource "aws_security_group" "private_web_sg" {
  name        = "private_web_sg"
  description = "Security group for private web server"
  vpc_id      = aws_vpc.main.id
  
  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }
  
  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "private-web-sg"
  }
}

# Private EC2 instance
resource "aws_instance" "private_web_server" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.private_web_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  
  # Explicitly disable public IP assignment
  associate_public_ip_address = false
  
  root_block_device {
    volume_size = 8
    encrypted   = false
  }
  
  tags = {
    Name = "private-web-server"
  }
}

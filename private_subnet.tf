
# Private subnet configuration for web server
resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.main.id
  cidr_block             = "10.0.4.0/24"
  availability_zone      = "us-east-1a"
  map_public_ip_on_launch = false
  
  tags = {
    Name = "private-subnet"
  }
}

# Private route table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  
  tags = {
    Name = "private-route-table"
  }
}

# Associate private subnet with private route table
resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

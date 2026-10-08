resource "aws_security_group" "vpc_endpoints" {
  name        = "devops-vpc-endpoints-sg"
  description = "Allow HTTPS from backend instances to VPC endpoints"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "HTTPS from frontend"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend.id]
  }
  ingress {
    description     = "HTTPS from backend"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.backend.id]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "devops-vpc-endpoints-sg"
  }
}

resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.eu-north-1.ecr.api"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id
  ]

  security_group_ids = [
    aws_security_group.vpc_endpoints.id
  ]

  tags = {
    Name = "devops-ecr-api-endpoint"
  }
}
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.eu-north-1.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id
  ]

  security_group_ids = [
    aws_security_group.vpc_endpoints.id
  ]

  tags = {
    Name = "devops-ecr-dkr-endpoint"
  }
}
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.eu-north-1.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [
    aws_route_table.private.id
  ]

  tags = {
    Name = "devops-s3-endpoint"
  }
}
resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.eu-north-1.ssm"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id
  ]

  security_group_ids = [
    aws_security_group.vpc_endpoints.id
  ]

  tags = {
    Name = "devops-ssm-endpoint"
  }
}

resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.eu-north-1.ssmmessages"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id
  ]

  security_group_ids = [
    aws_security_group.vpc_endpoints.id
  ]

  tags = {
    Name = "devops-ssmmessages-endpoint"
  }
}

resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.eu-north-1.ec2messages"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id
  ]

  security_group_ids = [
    aws_security_group.vpc_endpoints.id
  ]

  tags = {
    Name = "devops-ec2messages-endpoint"
  }
}
resource "aws_vpc_endpoint" "sts" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.eu-north-1.sts"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id
  ]

  security_group_ids = [
    aws_security_group.vpc_endpoints.id
  ]

  tags = {
    Name = "devops-sts-endpoint"
  }
}

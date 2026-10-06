resource "aws_instance" "frontend" {
  ami           = "ami-0f980b876fce6ce35"
  instance_type = "t3.micro"

  subnet_id = aws_subnet.public_a.id

  vpc_security_group_ids = [
    aws_security_group.frontend.id
  ]

  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash
              dnf update -y
              dnf install -y nginx
              systemctl enable nginx
              systemctl start nginx

              cat > /usr/share/nginx/html/index.html <<'HTML'
              <html>
                <head>
                  <title>DevOps Terraform Lab</title>
                </head>
                <body>
                  <h1>Terraform EC2 is working!</h1>
                  <p>VPC: 10.0.0.0/16</p>
                  <p>Subnet: Public-A</p>
                </body>
              </html>
              HTML
              EOF

  tags = {
    Name = "devops-frontend"
  }
}

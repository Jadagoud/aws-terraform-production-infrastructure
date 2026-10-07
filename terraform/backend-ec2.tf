resource "aws_instance" "backend" {
  ami           = "ami-0f980b876fce6ce35"
  instance_type = "t3.micro"

  subnet_id = aws_subnet.private_a.id

  vpc_security_group_ids = [
    aws_security_group.backend.id
  ]

  iam_instance_profile = aws_iam_instance_profile.backend_ec2.name

  user_data = <<-EOF
              #!/bin/bash
              echo "Backend EC2 is running" > /tmp/backend-status.txt
              EOF

  tags = {
    Name = "devops-backend"
  }
}

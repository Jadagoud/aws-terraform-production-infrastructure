resource "aws_launch_template" "frontend" {
  name_prefix   = "devops-frontend-"
  image_id      = "ami-0f980b876fce6ce35"
  instance_type = "t3.micro"

  iam_instance_profile {
    name = aws_iam_instance_profile.frontend_ec2.name
  }

  vpc_security_group_ids = [
    aws_security_group.frontend.id
  ]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -euxo pipefail

    # Install Docker
    dnf install -y docker

    # Start Docker
    systemctl enable docker
    systemctl start docker

    # Wait until Docker daemon is ready
    until sudo docker info >/dev/null 2>&1; do
      sleep 2
    done

    # Install and start SSM Agent
    dnf install -y amazon-ssm-agent
    systemctl enable amazon-ssm-agent
    systemctl start amazon-ssm-agent

    # Login to Amazon ECR
    aws ecr get-login-password --region eu-north-1 | \
      sudo docker login --username AWS --password-stdin \
      451782721795.dkr.ecr.eu-north-1.amazonaws.com

    # Pull React frontend
    sudo docker pull \
      451782721795.dkr.ecr.eu-north-1.amazonaws.com/devops-frontend:latest

    # Run frontend
    sudo docker run -d \
      --name frontend \
      --restart unless-stopped \
      -p 80:80 \
      451782721795.dkr.ecr.eu-north-1.amazonaws.com/devops-frontend:latest
  EOF
  )

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "devops-frontend-asg"
    }
  }
}

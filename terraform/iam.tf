resource "aws_iam_role" "backend_ec2" {
  name = "devops-backend-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "devops-backend-ec2-role"
  }
}

resource "aws_iam_instance_profile" "backend_ec2" {
  name = "devops-backend-ec2-profile"
  role = aws_iam_role.backend_ec2.name
}
resource "aws_iam_role_policy_attachment" "backend_ssm" {
  role       = aws_iam_role.backend_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

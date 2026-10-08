resource "aws_autoscaling_group" "frontend" {
  name = "devops-frontend-asg"

  min_size         = 1
  desired_capacity = 2
  max_size         = 2

  vpc_zone_identifier = [
    aws_subnet.public_a.id,
    aws_subnet.public_b.id
  ]

  target_group_arns = [
    aws_lb_target_group.frontend.arn
  ]

  health_check_type         = "ELB"
  health_check_grace_period = 180

  launch_template {
    id      = aws_launch_template.frontend.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "devops-frontend-asg"
    propagate_at_launch = true
  }
}

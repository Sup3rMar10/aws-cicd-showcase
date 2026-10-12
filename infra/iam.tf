locals {
  ecs_tasks_trust = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Used by ECS itself to pull the image from ECR and write logs.
resource "aws_iam_role" "execution" {
  name               = "${var.name}-execution"
  assume_role_policy = local.ecs_tasks_trust
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# The identity of the running application. It has no permissions because this app calls no AWS APIs;
# a real app would get exactly the access it needs here (for example one S3 bucket or one DynamoDB table).
resource "aws_iam_role" "task" {
  name               = "${var.name}-task"
  assume_role_policy = local.ecs_tasks_trust
}

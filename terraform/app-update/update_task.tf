variable "image_tag" {
  description = "Tag da imagem Docker"
  type        = string
}

data "aws_iam_role" "ecs_task_execution" {
  name = "ecsTaskExecutionRoleByTf"
}

data "aws_iam_role" "ecs_task_role" {
  name = "ecsTaskRole"
}

resource "aws_ecs_task_definition" "dotgroup_app_update" {
  family                   = "dotgroup-app-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"

  execution_role_arn = data.aws_iam_role.ecs_task_execution.arn
  task_role_arn      = data.aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([{
    name      = "dotgroup-app"
    image     = "lucasrsousa21/dotgroup-app-devops:${var.image_tag}"
    essential = true
    portMappings = [{
      containerPort = 8080
      hostPort      = 8080
    }]
  }])
}

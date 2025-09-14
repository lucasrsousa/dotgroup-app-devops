############################################
# ECS Cluster
############################################
resource "aws_ecs_cluster" "dotgroup-prod" {
  name = "dotgroup-prod-cluster"
}

############################################
# ECS Task Definition
############################################
resource "aws_ecs_task_definition" "dotgroup-app" {
  family                   = "dotgroup-app-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"

  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "dotgroup-app"
      image     = "lucasrsousa21/dotgroup-app-teste-tecnico:latest"
      essential = true
      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
        }
      ]
    }
  ])
}

############################################
# ECS Service
############################################
resource "aws_ecs_service" "dotgroup-app" {
  name            = "dotgroup-app-service"
  cluster         = aws_ecs_cluster.dotgroup-prod.id
  task_definition = aws_ecs_task_definition.dotgroup-app.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = [
      aws_subnet.subnet-private-a.id,
      aws_subnet.subnet-private-b.id
    ]
    security_groups  = [aws_security_group.dotgroup-app-prod-sg.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "dotgroup-app"
    container_port   = 8080
  }

  depends_on = [
    aws_lb_listener.app
  ]
}
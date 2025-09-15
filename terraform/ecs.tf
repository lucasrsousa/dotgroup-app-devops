############################################
# ECS Cluster
############################################
resource "aws_ecs_cluster" "dotgroup-prod" {
  name = "dotgroup-prod-cluster"
}

############################################
# CloudWatch Log Group
############################################
resource "aws_cloudwatch_log_group" "dotgroup_app" {
  name              = "/ecs/dotgroup-app"
  retention_in_days = 3 
}

############################################
# IAM Role - Permissão de Logs
############################################
resource "aws_iam_role_policy_attachment" "ecs_task_execution_logs" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

############################################
# ECS Task Definition
############################################
variable "image_tag" {
  description = "Tag da imagem Docker"
  type        = string
  default     = "latest"
}

resource "aws_ecs_task_definition" "dotgroup-app" {
  family                   = "dotgroup-app-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"

  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn      = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "dotgroup-app"
      image     = "lucasrsousa21/dotgroup-app-devops:${var.image_tag}"
      essential = true
      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
        }
      ]
      environment = [
        {
          name  = "VARIAVEL_FAKE_1"
          value = "value1"
        },
        {
          name  = "VARIAVEL_FAKE_2"
          value = "value2"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.dotgroup_app.name
          awslogs-region        = "us-east-1"
          awslogs-stream-prefix = "ecs"
        }
      }
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

############################################
# Auto Scaling Target
############################################
resource "aws_appautoscaling_target" "ecs_dotgroup_target" {
  max_capacity       = 2
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.dotgroup-prod.name}/${aws_ecs_service.dotgroup-app.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

############################################
# Auto Scaling Policy - CPU
############################################
resource "aws_appautoscaling_policy" "ecs_dotgroup_cpu_scale_up" {
  name               = "cpu-scale-up"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_dotgroup_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_dotgroup_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_dotgroup_target.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 70.0       # % de CPU
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    scale_in_cooldown  = 240
    scale_out_cooldown = 240
  }
}

############################################
# DNS domain
############################################
output "alb_dns_name" {
  value = aws_lb.app.dns_name
}

############################################
# Output do ECS Service e Cluster
############################################
output "ecs_cluster_name" {
  value = aws_ecs_cluster.dotgroup-prod.name
}

output "ecs_service_name" {
  value = aws_ecs_service.dotgroup-app.name
}
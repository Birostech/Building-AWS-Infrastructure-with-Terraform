output "rds_endpoint" {
  description = "The RDS endpoint"
  value       = aws_db_instance.rds_instance.endpoint
}

output "load_balancer_dns" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.load_balancer.dns_name
}



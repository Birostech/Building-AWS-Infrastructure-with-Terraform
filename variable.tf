variable "aws_region" {
  description = "region to launch my instance"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.macro"
}



variable "private_subnet_cidr" {
  description = "private subnet cidr block"
  type        = string
  sensitive   = true
}

variable "private_subnet_cidr_2" {
  description = "private subnet 2 cidr block"
  type        = string
  sensitive   = true
}

variable "rds_port" {
  description = "ports for the rds"
  type        = number
  sensitive   = true
}

variable "db_username" {
  description = "db username"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "db password"
  type        = string
  sensitive   = true
}

variable "private_ec2_port" {
  description = "ports for the private ec2"
  type        = number
  sensitive   = true
}

variable "private_ec2_port_2" {
  description = "ports for second private ec2 "
  type        = number
  sensitive   = true
}

variable "key_name" {
  description = "ec2 key name"
  type        = string
  sensitive   = true
}
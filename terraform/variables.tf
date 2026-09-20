variable "project_name" { default = "depi-sec" }
variable "region" { default = "us-east-1" }
variable "vpc_cidr" { default = "10.0.0.0/16" }
variable "alert_email" { description = "Email for alerts" }
variable "rds_password" {
  description = "Master password for the RDS MySQL instance"
  type        = string
  sensitive   = true
}

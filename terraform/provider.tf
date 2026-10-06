provider "aws" {
  region = "eu-north-1"

  default_tags {
    tags = {
      Project     = "aws-terraform-production-infrastructure"
      Environment = "dev"
      ManagedBy   = "Terraform"
    }
  }
}

terraform {
  backend "s3" {
    bucket       = "aws-terraform-production-infrastructure-tfstate-451782721795"
    key          = "terraform/terraform.tfstate"
    region       = "eu-north-1"
    use_lockfile = true
  }
}

terraform {
  backend "s3" {
    bucket = "nt548-terraform-state-bucket"
    key    = "devops-project/prod/terraform.tfstate" 
    region = "ap-southeast-1"
    dynamodb_table = "terraform-lock"
    encrypt = true
  }
}
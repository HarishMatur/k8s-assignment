terraform {
  backend "s3" {
    bucket       = "k8s-assignment-bucket"
    key          = "k8s-assignment/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true
  }
}
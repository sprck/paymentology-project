terraform {
  # required_version = ">=1.10.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
    source  = "hashicorp/random"
    version = "~> 3.0"
  }
}

  backend "s3" {
    bucket         = "pay-app-backend1"
    key            = "pay-app-backend1/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "pay-app-statelock-DB"
    encrypt        = true
  }
}

provider "aws" {
  region = "us-east-1"
} 

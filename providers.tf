terraform {
  cloud {
    organization = "027-spring-cloud" # uzgartir

    workspaces {
      name = "aug-28-2024" # uzgartir
    }
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
provider "aws" {
  region = "us-east-1"
}
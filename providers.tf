terraform {
  cloud {
    organization = "donis_cloud" # changed  

    workspaces {
      name = "apple_workspace_created_by_terraform" # changed
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
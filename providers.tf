terraform {
  cloud {
    organization = "donis_cloud" # change  

    workspaces {
      name = "apple_workspace_created_by_terraform" # uzgartirdim
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
terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0" # MCP Server で最新を確認して更新してください
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      Project     = "ai-app"
      ManagedBy   = "Terraform"
      Owner       = "ai-team"
      CostCenter  = var.cost_center
    }
  }
}

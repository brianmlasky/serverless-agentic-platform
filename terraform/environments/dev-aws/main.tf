terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "gcs" {
    bucket = "alert-hall-466720-c0-terraform-state"
    prefix = "environments/dev-aws"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      Project     = "serverless-agentic-platform"
      ManagedBy   = "terraform"
    }
  }
}

module "aws_iam" {
  source = "../../modules/aws-iam"

  aws_account_id      = var.aws_account_id
  admin_user_name     = var.admin_user_name
  gcp_project_id      = var.gcp_project_id
  gcp_region          = var.gcp_region
  gke_cluster_name    = var.gke_cluster_name
  k8s_namespace       = var.k8s_namespace
  k8s_service_account = var.k8s_service_account
  environment         = var.environment
}

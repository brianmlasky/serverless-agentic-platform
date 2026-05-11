variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "environment" {
  description = "Environment name (dev/prod)"
  type        = string
  default     = "dev"
}

variable "gke_workload_sa_email" {
  description = "GKE Workload Service Account email"
  type        = string
}

variable "litellm_sa_email" {
  description = "LiteLLM Service Account email"
  type        = string
}

variable "aws_region" {
  description = "AWS region for provider configuration"
  type        = string
  default     = "us-east-1"
}

variable "aws_account_id" {
  description = "AWS Account ID"
  type        = string
}

variable "gke_cluster_name" {
  description = "Name of the existing GKE cluster (used for AWS OIDC trust policy)"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository in owner/repo format for WIF attribute condition"
  type        = string
  default     = "brianmlasky/serverless-agentic-platform"
}

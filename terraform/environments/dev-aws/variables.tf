variable "aws_region" {
  description = "AWS region for provider"
  type        = string
  default     = "us-east-1"
}

variable "aws_account_id" {
  description = "AWS Account ID"
  type        = string
}

variable "admin_user_name" {
  description = "IAM admin user to receive Marketplace policy"
  type        = string
}

variable "gcp_project_id" {
  description = "GCP project ID (used to construct OIDC provider ARN)"
  type        = string
}

variable "gcp_region" {
  description = "GCP region where GKE cluster runs"
  type        = string
}

variable "gke_cluster_name" {
  description = "GKE cluster name"
  type        = string
}

variable "k8s_namespace" {
  description = "Kubernetes namespace"
  type        = string
  default     = "litellm"
}

variable "k8s_service_account" {
  description = "Kubernetes service account name"
  type        = string
  default     = "litellm-sa"
}

variable "environment" {
  description = "Environment label"
  type        = string
  default     = "dev"
}

variable "aws_account_id" {
  description = "AWS Account ID"
  type        = string
}

variable "admin_user_name" {
  description = "IAM user to attach admin policies to"
  type        = string
}

variable "gcp_project_id" {
  description = "GCP Project ID (used in OIDC provider ARN)"
  type        = string
}

variable "gcp_region" {
  description = "GCP Region where GKE cluster runs"
  type        = string
}

variable "gke_cluster_name" {
  description = "GKE cluster name"
  type        = string
}

variable "k8s_namespace" {
  description = "Kubernetes namespace for LiteLLM"
  type        = string
  default     = "litellm"
}

variable "k8s_service_account" {
  description = "Kubernetes service account name for LiteLLM"
  type        = string
  default     = "litellm-sa"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "gke_oidc_provider_arn" {
  description = "ARN of the GKE OIDC provider in AWS IAM (passed directly to avoid data source lookup)"
  type        = string
}

variable "gke_oidc_provider_url" {
  description = "URL of the GKE OIDC provider without https:// (used as condition key prefix)"
  type        = string
}

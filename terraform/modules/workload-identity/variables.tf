variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "k8s_namespace" {
  description = "Kubernetes namespace where LiteLLM runs"
  type        = string
  default     = "litellm"
}

variable "k8s_service_account" {
  description = "Kubernetes service account name for LiteLLM"
  type        = string
  default     = "litellm-sa"
}

variable "gke_cluster_dependency" {
  description = "GKE cluster name — used only as a depends_on anchor"
  type        = string
  default     = ""
}

variable "environment" {
  description = "Environment name (e.g. dev, prod)"
  type        = string
  default     = "dev"
}

variable "aws_role_arn" {
  description = "AWS IAM role ARN from aws_iam module — passed through as output"
  type        = string
  default     = ""
}

variable "project_roles" {
  description = "List of IAM roles to grant to the litellm GSA at project level."
  type        = list(string)
  default     = []
}

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "aws_region" {
  description = "AWS region for Bedrock access"
  type        = string
  default     = "us-east-1"
}

variable "aws_role_name" {
  description = "AWS IAM role name for Bedrock access"
  type        = string
  default     = "dev-litellm-bedrock-role"
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

# Accepts the GKE cluster ID as a dependency anchor.
# depends_on in the IAM binding references this variable to force
# correct ordering — WIF pool must exist before the binding is created.
variable "gke_cluster_dependency" {
  description = "GKE cluster name — used only as a depends_on anchor to ensure the Workload Identity Pool exists before the IAM binding is created"
  type        = string
  default     = ""
}

variable "aws_account_id" {
  description = "AWS account ID used to scope Bedrock ARN conditions"
  type        = string
}

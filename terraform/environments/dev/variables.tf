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

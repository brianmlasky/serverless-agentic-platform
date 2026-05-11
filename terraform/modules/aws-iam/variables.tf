variable "environment" {
  description = "Environment name"
  type        = string
}

variable "aws_account_id" {
  description = "AWS Account ID"
  type        = string
}

variable "gke_cluster_project" {
  description = "GCP project ID hosting the GKE cluster"
  type        = string
}

variable "gke_cluster_location" {
  description = "GCP region/zone of the GKE cluster"
  type        = string
}

variable "gke_cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
}

variable "k8s_namespace" {
  description = "Kubernetes namespace of the workload"
  type        = string
  default     = "litellm"
}

variable "k8s_service_account" {
  description = "Kubernetes service account name"
  type        = string
  default     = "litellm-sa"
}

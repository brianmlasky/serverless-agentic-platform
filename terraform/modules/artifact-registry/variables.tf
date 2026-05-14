variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "environment" {
  type = string
}

variable "repository_id" {
  description = "Artifact Registry repository name"
  type        = string
  default     = "portfolio-images"
}

variable "reader_service_accounts" {
  description = "List of service account emails to grant roles/artifactregistry.reader on this repository"
  type        = list(string)
  default     = []
}

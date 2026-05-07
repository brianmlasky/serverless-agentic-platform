variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "network_name" {
  description = "VPC network name"
  type        = string
  default     = "main-vpc"
}

variable "subnet_cidr" {
  description = "Primary subnet CIDR"
  type        = string
  default     = "10.0.0.0/20"
}

variable "pods_cidr" {
  description = "GKE pods secondary range CIDR"
  type        = string
  default     = "10.16.0.0/14"
}

variable "services_cidr" {
  description = "GKE services secondary range CIDR"
  type        = string
  default     = "10.20.0.0/20"
}

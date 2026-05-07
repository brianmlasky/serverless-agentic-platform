variable "project_id"           { type = string }
variable "region"               { type = string }
variable "environment"          { type = string }
variable "network_name"         { type = string }
variable "subnetwork_name"      { type = string }
variable "pods_range_name"      { type = string }
variable "services_range_name"  { type = string }
variable "workload_sa_email"    { type = string }

variable "cluster_name" {
  type    = string
  default = "portfolio-cluster"
}

variable "release_channel" {
  description = "GKE release channel"
  type        = string
  default     = "REGULAR"
}

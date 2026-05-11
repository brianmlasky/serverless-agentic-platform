output "network_id" {
  description = "VPC network ID"
  value       = google_compute_network.main.id
}

output "network_name" {
  description = "VPC network name"
  value       = google_compute_network.main.name
}

output "subnetwork_id" {
  description = "Subnet ID"
  value       = google_compute_subnetwork.main.id
}

output "subnetwork_name" {
  description = "Subnet name"
  value       = google_compute_subnetwork.main.name
}

output "pods_range_name" {
  description = "Secondary range name for GKE pods"
  value       = "${var.environment}-pods"
}

output "services_range_name" {
  description = "Secondary range name for GKE services"
  value       = "${var.environment}-services"
}

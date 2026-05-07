output "gke_cluster_name" {
  value = module.gke_autopilot.cluster_name
}

output "artifact_registry_url" {
  value = module.artifact_registry.repository_url
}

output "network_name" {
  value = module.networking.network_name
}

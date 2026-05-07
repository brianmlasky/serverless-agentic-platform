output "repository_id" {
  value = google_artifact_registry_repository.main.repository_id
}

output "repository_url" {
  description = "Full URL for docker push/pull"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.main.repository_id}"
}

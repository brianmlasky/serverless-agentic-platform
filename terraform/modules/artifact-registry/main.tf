resource "google_artifact_registry_repository" "main" {
  provider      = google
  project       = var.project_id
  location      = var.region
  repository_id = "${var.environment}-${var.repository_id}"
  description   = "Docker images for ${var.environment} environment"
  format        = "DOCKER"

  docker_config {
    immutable_tags = false
  }

  cleanup_policies {
    id     = "keep-minimum-versions"
    action = "KEEP"
    most_recent_versions {
      keep_count = 5
    }
  }
}

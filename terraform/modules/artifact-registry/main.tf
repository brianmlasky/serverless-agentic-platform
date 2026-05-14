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

# Resolve project number so we can derive the default Compute Engine SA
data "google_project" "main" {
  project_id = var.project_id
}

# Grant roles/artifactregistry.reader to every SA in var.reader_service_accounts
resource "google_artifact_registry_repository_iam_member" "readers" {
  for_each = toset(var.reader_service_accounts)

  project    = var.project_id
  location   = var.region
  repository = google_artifact_registry_repository.main.repository_id
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${each.value}"
}

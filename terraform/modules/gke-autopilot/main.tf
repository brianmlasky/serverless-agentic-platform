# ============================================================
# GKE Autopilot Cluster
# ============================================================
resource "google_container_cluster" "main" {
  provider    = google-beta
  name        = "${var.environment}-${var.cluster_name}"
  location    = var.region
  project     = var.project_id
  description = "Autopilot cluster. Google manages nodes. We own workload identity and network policy."

  # Autopilot mode - Google manages nodes
  enable_autopilot = true

  # Network configuration
  network    = var.network_name
  subnetwork = var.subnetwork_name

  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }

  # Private cluster - nodes have no public IPs
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false  # Public endpoint for kubectl access
  }

  # Release channel for automatic upgrades
  release_channel {
    channel = var.release_channel
  }

  # Workload Identity - enables GKE pods to use GCP IAM
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Security: enable binary authorization
  binary_authorization {
    evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
  }

  # Logging and monitoring
  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]
    managed_prometheus {
      enabled = true
    }
  }

  lifecycle {
    ignore_changes = [
      # Autopilot manages these automatically
      node_config,
    ]
  }
}

# ============================================================
# Workload Identity Binding
# Allows GKE pods (via K8s SA) to impersonate GCP SA
# ============================================================
resource "google_service_account_iam_member" "workload_identity" {
  service_account_id = "projects/${var.project_id}/serviceAccounts/${var.workload_sa_email}"
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[default/litellm-sa]"
}

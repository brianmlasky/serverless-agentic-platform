# ============================================================
# VPC Network
# ============================================================
resource "google_compute_network" "main" {
  name                    = "${var.environment}-${var.network_name}"
  auto_create_subnetworks = false
  project                 = var.project_id

  lifecycle {
    prevent_destroy = false
  }
}

# ============================================================
# Subnet with secondary ranges for GKE
# ============================================================
resource "google_compute_subnetwork" "main" {
  name          = "${var.environment}-main-subnet"
  ip_cidr_range = var.subnet_cidr
  region        = var.region
  network       = google_compute_network.main.id
  project       = var.project_id

  # Required for GKE Autopilot
  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = var.pods_cidr
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = var.services_cidr
  }

  private_ip_google_access = true
}

# ============================================================
# Cloud Router + NAT (for private GKE nodes to reach internet)
# ============================================================
resource "google_compute_router" "main" {
  name    = "${var.environment}-router"
  region  = var.region
  network = google_compute_network.main.id
  project = var.project_id
}

resource "google_compute_router_nat" "main" {
  name                               = "${var.environment}-nat"
  router                             = google_compute_router.main.name
  region                             = var.region
  project                            = var.project_id
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

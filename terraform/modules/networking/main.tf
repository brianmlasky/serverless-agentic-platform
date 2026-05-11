# ============================================================
# VPC Network
# ============================================================
resource "google_compute_network" "main" {
  name                    = "${var.environment}-${var.network_name}"
  auto_create_subnetworks = false
  project                 = var.project_id
  description             = "Private VPC. No default routes. Egress controlled by NAT."

  lifecycle {
    prevent_destroy = false
  }
}

# ============================================================
# Subnet with secondary ranges for GKE
# ============================================================
resource "google_compute_subnetwork" "main" {
  name          = "${var.environment}-subnet-${var.region}"
  ip_cidr_range = var.subnet_cidr
  region        = var.region
  network       = google_compute_network.main.id
  project       = var.project_id

  secondary_ip_range {
    range_name    = "${var.environment}-pods"
    ip_cidr_range = var.pods_cidr
  }

  secondary_ip_range {
    range_name    = "${var.environment}-services"
    ip_cidr_range = var.services_cidr
  }

  private_ip_google_access = true
}

# ============================================================
# Cloud Router + NAT
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

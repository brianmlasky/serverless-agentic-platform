terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
  }

  backend "gcs" {
    bucket = "alert-hall-466720-c0-terraform-state"
    prefix = "environments/dev"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

# ── Networking ─────────────────────────────────────────────
module "networking" {
  source      = "../../modules/networking"
  project_id  = var.project_id
  region      = var.region
  environment = var.environment
}

# ── Artifact Registry ──────────────────────────────────────
module "artifact_registry" {
  source      = "../../modules/artifact-registry"
  project_id  = var.project_id
  region      = var.region
  environment = var.environment
}

# ── GKE Autopilot ──────────────────────────────────────────
module "gke_autopilot" {
  source               = "../../modules/gke-autopilot"
  project_id           = var.project_id
  region               = var.region
  environment          = var.environment
  network_name         = module.networking.network_name
  subnetwork_name      = module.networking.subnetwork_name
  pods_range_name      = module.networking.pods_range_name
  services_range_name  = module.networking.services_range_name
  workload_sa_email    = var.gke_workload_sa_email

  depends_on = [module.networking]
}

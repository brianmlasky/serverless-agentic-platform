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
    aws = {
      source  = "hashicorp/aws"
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

provider "aws" {
  region = var.aws_region
}

# ── Networking ─────────────────────────────────────────────────────────────
module "networking" {
  source      = "../../modules/networking"
  project_id  = var.project_id
  region      = var.region
  environment = var.environment
}

# ── Artifact Registry ──────────────────────────────────────────────────────
module "artifact_registry" {
  source      = "../../modules/artifact-registry"
  project_id  = var.project_id
  region      = var.region
  environment = var.environment
}

# ── GKE Autopilot ─────────────────────────────────────────────────────────
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

# ── AWS IAM (Bedrock access via GKE Workload Identity) ────────────────────
module "aws_iam" {
  source = "../../modules/aws-iam"

  environment          = var.environment
  aws_account_id       = var.aws_account_id
  gke_cluster_project  = var.project_id
  gke_cluster_location = var.region
  gke_cluster_name     = var.gke_cluster_name
  k8s_namespace        = "litellm"
  k8s_service_account  = "litellm-sa"

}

# ── GitHub Actions CI/CD Service Account ──────────────────────────────────
resource "google_service_account" "github_actions_sa" {
  project      = var.project_id
  account_id   = "github-actions-sa"
  display_name = "GitHub Actions CI/CD Service Account"
  description  = "Impersonated by GitHub Actions via Workload Identity Federation"
}

resource "google_project_iam_member" "github_actions_registry_writer" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.github_actions_sa.email}"
}

resource "google_project_iam_member" "github_actions_gke_developer" {
  project = var.project_id
  role    = "roles/container.developer"
  member  = "serviceAccount:${google_service_account.github_actions_sa.email}"
}

resource "google_iam_workload_identity_pool" "github_pool" {
  project                   = var.project_id
  workload_identity_pool_id = "github-actions-pool"
  display_name              = "GitHub Actions Pool"
  description               = "WIF pool for GitHub Actions OIDC"
}

resource "google_iam_workload_identity_pool_provider" "github_provider" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github_pool.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"
  display_name                       = "GitHub Actions OIDC Provider"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.repository" = "assertion.repository"
  }

  attribute_condition = "assertion.repository == '${var.github_repo}'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account_iam_member" "github_actions_wif_binding" {
  service_account_id = google_service_account.github_actions_sa.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github_pool.name}/attribute.repository/${var.github_repo}"
}

# ── LiteLLM Workload Identity (GKE pods → AWS Bedrock) ────────────────────
module "workload_identity" {
  source = "../../modules/workload-identity"

  project_id             = var.project_id
  aws_role_arn           = module.aws_iam.role_arn
  k8s_namespace          = "litellm"
  k8s_service_account    = "litellm-sa"
  environment            = var.environment
  gke_cluster_dependency = module.gke_autopilot.cluster_name

  depends_on = [module.gke_autopilot, module.aws_iam]
}

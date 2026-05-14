# ── GCP SIDE ──────────────────────────────────────────────────────────────────

resource "google_service_account" "litellm" {
  account_id   = "litellm-wif-sa"
  display_name = "LiteLLM Workload Identity SA"
  description  = "Assumed by GKE pods via WIF. Federates to AWS for Bedrock access."
  project      = var.project_id
}

# depends_on forces Terraform to wait until the GKE cluster is fully
# provisioned before attempting to bind the Workload Identity Pool member.
# The pool (project.svc.id.goog) is created by GKE during cluster creation —
# it does not exist until the cluster API reports RUNNING.
resource "google_service_account_iam_binding" "workload_identity_binding" {
  service_account_id = google_service_account.litellm.name
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "serviceAccount:${var.project_id}.svc.id.goog[${var.k8s_namespace}/${var.k8s_service_account}]"
  ]

  # The WIF pool (project.svc.id.goog) is created by GKE during cluster
  # provisioning. Without this explicit dependency, Terraform may attempt
  # the IAM binding before the pool exists, causing a 400 badRequest.
  depends_on = [var.gke_cluster_dependency]
}

# ── PROJECT-LEVEL ROLES ───────────────────────────────────────────────────────
# Grant each role in var.project_roles to the litellm GSA.
# Using google_project_iam_member (additive) so other bindings are not clobbered.
resource "google_project_iam_member" "litellm_project_roles" {
  for_each = toset(var.project_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.litellm.email}"
}

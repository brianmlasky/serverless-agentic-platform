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


# ── AWS SIDE ──────────────────────────────────────────────────────────────────

resource "aws_iam_openid_connect_provider" "gcp" {
  url = "https://container.googleapis.com/v1/projects/alert-hall-466720-c0/locations/us-central1/clusters/dev-gke-cluster"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  thumbprint_list = ["218369dfac5b8f448ee0b5d7ea45409618d8ce19"]
}

resource "aws_iam_role" "bedrock_access" {
  name        = var.aws_role_name
  description = "Assumed by GKE pod via OIDC WIF - grants Bedrock access"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "GKEWorkloadIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.gcp.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "container.googleapis.com/v1/projects/alert-hall-466720-c0/locations/us-central1/clusters/dev-gke-cluster:aud" = "sts.amazonaws.com"
            "container.googleapis.com/v1/projects/alert-hall-466720-c0/locations/us-central1/clusters/dev-gke-cluster:sub" = "system:serviceaccount:litellm:litellm-sa"
          }
        }
      }
    ]
  })
  tags = {
    Environment = "dev"
    ManagedBy   = "terraform"
    Project     = "serverless-agentic-platform"
    Purpose     = "litellm-bedrock-wif"
  }
}

resource "aws_iam_role_policy" "bedrock_invoke" {
  name = "bedrock-invoke-policy"
  role = aws_iam_role.bedrock_access.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "BedrockFoundationModels"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream",
        ]
        Resource = [
          "arn:aws:bedrock:*::foundation-model/*",
        ]
      },
      {
        Sid    = "BedrockInferenceProfiles"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream",
        ]
        Resource = [
          "arn:aws:bedrock:*:${var.aws_account_id}:inference-profile/us.anthropic.*",
        ]
      },
      {
        Sid    = "BedrockInferenceProfileRead"
        Effect = "Allow"
        Action = [
          "bedrock:ListInferenceProfiles",
          "bedrock:GetInferenceProfile",
        ]
        Resource = "*"
      },
    ]
  })
}

# ── Data Sources ───────────────────────────────────────────────────────────────

# Existing GKE OIDC provider (created out-of-band, imported into state)
data "aws_iam_openid_connect_provider" "gke" {
  arn = "arn:aws:iam::${var.aws_account_id}:oidc-provider/container.googleapis.com/v1/projects/${var.gcp_project_id}/locations/${var.gcp_region}/clusters/${var.gke_cluster_name}"
}

# ── IAM Role: LiteLLM Bedrock Access ──────────────────────────────────────────

locals {
  gke_oidc_url = trimprefix(data.aws_iam_openid_connect_provider.gke.url, "https://")
  # Subject claim format for GKE Workload Identity tokens
  k8s_subject = "system:serviceaccount:${var.k8s_namespace}:${var.k8s_service_account}"
}

resource "aws_iam_role" "litellm_bedrock" {
  name        = "${var.environment}-litellm-bedrock-role"
  description = "Assumed by GKE pod via OIDC WIF - grants Bedrock access"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "GKEWorkloadIdentity"
        Effect = "Allow"
        Principal = {
          Federated = data.aws_iam_openid_connect_provider.gke.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${local.gke_oidc_url}:sub" = local.k8s_subject
            "${local.gke_oidc_url}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
    Purpose     = "litellm-bedrock-wif"
  }
}

# ── Bedrock Policy ─────────────────────────────────────────────────────────────

resource "aws_iam_policy" "bedrock_access" {
  name        = "${var.environment}-litellm-bedrock-policy"
  description = "Minimum permissions for LiteLLM to invoke Bedrock Claude models"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "BedrockInvoke"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Resource = [
          "arn:aws:bedrock:*::foundation-model/anthropic.claude-haiku-4-5-20251001-v1:0",
          "arn:aws:bedrock:*::foundation-model/anthropic.claude-sonnet-4-5-20250929-v1:0",
          "arn:aws:bedrock:*::foundation-model/anthropic.claude-opus-4-1-20250805-v1:0",
          "arn:aws:bedrock:us-east-1:229502947368:inference-profile/us.anthropic.claude-haiku-4-5-20251001-v1:0",
          "arn:aws:bedrock:us-east-1:229502947368:inference-profile/us.anthropic.claude-sonnet-4-5-20250929-v1:0",
          "arn:aws:bedrock:us-east-1:229502947368:inference-profile/us.anthropic.claude-opus-4-1-20250805-v1:0"
        ]
      }
    ]
  })

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role_policy_attachment" "litellm_bedrock" {
  role       = aws_iam_role.litellm_bedrock.name
  policy_arn = aws_iam_policy.bedrock_access.arn
}

# ── Admin User: Marketplace Policy ────────────────────────────────────────────

resource "aws_iam_user_policy_attachment" "admin_marketplace" {
  user       = var.admin_user_name
  policy_arn = "arn:aws:iam::aws:policy/AWSMarketplaceManageSubscriptions"
}

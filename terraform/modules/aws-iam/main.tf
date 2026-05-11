# ── Local derived values ────────────────────────────────────────────────────
locals {
  oidc_url = "container.googleapis.com/v1/projects/${var.gke_cluster_project}/locations/${var.gke_cluster_location}/clusters/${var.gke_cluster_name}"
  oidc_arn = "arn:aws:iam::${var.aws_account_id}:oidc-provider/${local.oidc_url}"
  role_name   = "${var.environment}-litellm-bedrock-role"
  policy_name = "${var.environment}-litellm-bedrock-policy"
}

# ── OIDC Identity Provider ──────────────────────────────────────────────────
resource "aws_iam_openid_connect_provider" "gke" {
  url = "https://${local.oidc_url}"

  client_id_list = ["sts.amazonaws.com"]

  # GKE uses Google's root CA thumbprint
  # This is stable for all GKE clusters — Google's root cert SHA-1
  thumbprint_list = ["08745487e891c19e3078c1f2a07e452950ef36f6"]

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# ── Trust policy ────────────────────────────────────────────────────────────
data "aws_iam_policy_document" "bedrock_trust" {
  statement {
    sid     = "GKEWorkloadIdentity"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_url}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_url}:sub"
      values   = ["system:serviceaccount:${var.k8s_namespace}:${var.k8s_service_account}"]
    }
  }
}

# ── IAM Role ────────────────────────────────────────────────────────────────
resource "aws_iam_role" "litellm_bedrock" {
  name               = local.role_name
  description        = "Assumed by GKE pod via OIDC WIF - grants Bedrock access"
  assume_role_policy = data.aws_iam_policy_document.bedrock_trust.json

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# ── Bedrock permission policy ────────────────────────────────────────────────
data "aws_iam_policy_document" "bedrock_permissions" {
  # Invoke any foundation model
  statement {
    sid    = "BedrockFoundationModels"
    effect = "Allow"
    actions = [
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream",
    ]
    resources = ["arn:aws:bedrock:*::foundation-model/*"]
  }

  # Invoke cross-region inference profiles (Anthropic family)
  statement {
    sid    = "BedrockInferenceProfiles"
    effect = "Allow"
    actions = [
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream",
    ]
    resources = ["arn:aws:bedrock:*:${var.aws_account_id}:inference-profile/us.anthropic.*"]
  }

  # Read-only metadata — required by LiteLLM model discovery
  statement {
    sid    = "BedrockMetadata"
    effect = "Allow"
    actions = [
      "bedrock:ListFoundationModels",
      "bedrock:GetFoundationModel",
      "bedrock:ListInferenceProfiles",
      "bedrock:GetInferenceProfile",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "litellm_bedrock" {
  name        = local.policy_name
  description = "Minimum permissions for LiteLLM to invoke Bedrock models"
  policy      = data.aws_iam_policy_document.bedrock_permissions.json

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# ── Attach managed policy to role ───────────────────────────────────────────
resource "aws_iam_role_policy_attachment" "litellm_bedrock" {
  role       = aws_iam_role.litellm_bedrock.name
  policy_arn = aws_iam_policy.litellm_bedrock.arn
}

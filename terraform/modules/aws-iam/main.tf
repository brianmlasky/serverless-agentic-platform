# Rationale: data "aws_iam_openid_connect_provider" requires iam:GetOpenIDConnectProvider
# at plan time. Since the ARN is deterministic from input variables,
# we pass it directly and avoid the live API call entirely.

locals {
  gke_oidc_url = var.gke_oidc_provider_url
  k8s_subject  = "system:serviceaccount:${var.k8s_namespace}:${var.k8s_service_account}"
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
          Federated = var.gke_oidc_provider_arn
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

resource "aws_iam_policy" "bedrock_access" {
  name        = "${var.environment}-litellm-bedrock-policy"
  description = "Minimum permissions for LiteLLM to invoke Bedrock models"

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

resource "aws_iam_user_policy_attachment" "admin_marketplace" {
  user       = var.admin_user_name
  policy_arn = "arn:aws:iam::aws:policy/AWSMarketplaceManageSubscriptions"
}

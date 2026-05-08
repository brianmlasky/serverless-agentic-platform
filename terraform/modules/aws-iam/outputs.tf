output "litellm_bedrock_role_arn" {
  description = "ARN of the IAM role assumed by LiteLLM pods"
  value       = aws_iam_role.litellm_bedrock.arn
}

output "litellm_bedrock_role_name" {
  description = "Name of the IAM role assumed by LiteLLM pods"
  value       = aws_iam_role.litellm_bedrock.name
}

output "bedrock_policy_arn" {
  description = "ARN of the Bedrock access policy"
  value       = aws_iam_policy.bedrock_access.arn
}

output "gke_oidc_provider_arn" {
  description = "ARN of the GKE OIDC provider (read-only data source)"
  value       = data.aws_iam_openid_connect_provider.gke.arn
}

output "role_arn" {
  description = "ARN of the IAM role assumed by LiteLLM pods"
  value       = aws_iam_role.litellm_bedrock.arn
}

output "role_name" {
  description = "Name of the IAM role"
  value       = aws_iam_role.litellm_bedrock.name
}

output "policy_arn" {
  description = "ARN of the managed Bedrock policy"
  value       = aws_iam_policy.litellm_bedrock.arn
}

output "oidc_provider_arn" {
  description = "ARN of the GKE OIDC provider"
  value       = aws_iam_openid_connect_provider.gke.arn
}

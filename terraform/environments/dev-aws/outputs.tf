output "litellm_bedrock_role_arn" {
  description = "Role ARN for LiteLLM → Bedrock WIF"
  value       = module.aws_iam.litellm_bedrock_role_arn
}

output "bedrock_policy_arn" {
  description = "Bedrock access policy ARN"
  value       = module.aws_iam.bedrock_policy_arn
}

output "gke_oidc_provider_arn" {
  description = "GKE OIDC provider ARN"
  value       = module.aws_iam.gke_oidc_provider_arn
}

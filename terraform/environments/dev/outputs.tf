output "gke_cluster_name" {
  value = module.gke_autopilot.cluster_name
}

output "artifact_registry_url" {
  value = module.artifact_registry.repository_url
}

output "network_name" {
  value = module.networking.network_name
}

output "aws_bedrock_role_arn" {
  description = "ARN of the IAM role for Bedrock access"
  value       = module.aws_iam.role_arn
}

output "aws_oidc_provider_arn" {
  description = "ARN of the GKE OIDC provider in AWS"
  value       = module.aws_iam.oidc_provider_arn
}

output "github_actions_sa_email" {
  description = "Email of the GitHub Actions service account (for GH Secret: GCP_SERVICE_ACCOUNT)"
  value       = google_service_account.github_actions_sa.email
}

output "workload_identity_provider" {
  description = "Full WIF provider resource name (for GH Secret: GCP_WORKLOAD_IDENTITY_PROVIDER)"
  value       = google_iam_workload_identity_pool_provider.github_provider.name
}

output "gcp_service_account_email" {
  description = "GCP SA email — annotated onto the K8s service account"
  value       = google_service_account.litellm.email
}

output "aws_role_arn" {
  description = "AWS role ARN — used by LiteLLM to call Bedrock"
  value       = aws_iam_role.bedrock_access.arn
}

output "aws_oidc_provider_arn" {
  description = "OIDC provider ARN — the AWS trust anchor for GCP tokens"
  value       = aws_iam_openid_connect_provider.gcp.arn
}

output "gcp_service_account_email" {
  description = "GCP SA email — annotated onto the K8s service account"
  value       = google_service_account.litellm.email
}

output "aws_role_arn" {
  description = "AWS role ARN — passed through from aws_iam module output"
  value       = var.aws_role_arn
}

# Project outputs for consumption by other systems or for reference

# GCP Project information
output "project_id" {
  value       = google_project.project.project_id
  description = "The ID of the created GCP project"
}

output "project_number" {
  value       = google_project.project.number
  description = "The numeric identifier of the created GCP project"
}

output "project_name" {
  value       = google_project.project.name
  description = "The display name of the created GCP project"
}

# Add additional outputs from modules as needed:
# output "bucket_names" {
#   value       = module.buckets.bucket_names
#   description = "List of created GCS bucket names"
# }

# output "service_accounts" {
#   value       = module.service_account.service_account_emails
#   description = "List of created service account emails"
# }

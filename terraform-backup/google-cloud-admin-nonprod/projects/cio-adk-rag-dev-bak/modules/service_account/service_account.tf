
# output bq service account email 
output "bq_service_account_email" {
  value = google_service_account.bq_service_account.email
}

# create bq service account
resource "google_service_account" "bq_service_account" {
  account_id                   = "bq-service-account"
  create_ignore_already_exists = true
  display_name                 = "BQ Service Account"
  project                      = var.common.project_id 
}



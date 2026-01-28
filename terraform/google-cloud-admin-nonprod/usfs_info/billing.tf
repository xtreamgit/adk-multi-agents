
# Billing outputs

output "billing_account_id_secret" {
  value = data.google_secret_manager_secret_version.billing_account_id_secret.secret_data
  sensitive = true
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

data "google_secret_manager_secret_version" "billing_account_id_secret" {
  secret = "projects/604060129428/secrets/Billing-Code-CLIN1-USFS-Stratus"
  version = "latest"
}
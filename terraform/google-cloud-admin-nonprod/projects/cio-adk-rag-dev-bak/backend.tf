terraform {
  backend "gcs" {
    bucket = "tfstate-dev-usfs-tf-admin"
    prefix = "usfs-gcp-arch-testing/terraform/state"
  }
}

# Note: Backend tfstate block writes to GCS bucket
# Bucket must be updated with admin tfstate bucket, cannot use variable
# Prefix must be updated with project name, cannot use variable
# To copy the existing state locally, use: terraform state pull >terraform.tfstate

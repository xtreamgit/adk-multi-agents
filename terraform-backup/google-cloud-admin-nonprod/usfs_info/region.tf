
# Region outputs
output "default_gcp_region" {value = var.default_gcp_region}
output "default_gcp_region_2" {value = var.default_gcp_region_2}
output "default_gcp_backup_region" {value = var.default_gcp_backup_region}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Default GCP region
variable "default_gcp_region" {
  description = "Default GCP region for most resources."
  type        = string
  default     = "us-central1"
}

# Default GCP region 2
variable "default_gcp_region_2" {
  description = "Default GCP region 2 for most resources."
  type        = string
  default     = "us-west1"
}


# Default GCP backup region
variable "default_gcp_backup_region" {
  description = "Default GCP backup region for most resources."
  type        = string
  default     = "us-west1"
}




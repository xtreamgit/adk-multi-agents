
# TF State outputs
output "bucket_name_tfstate_dev" {value = var.bucket_name_tfstate_dev}
output "bucket_name_tfstate_prod" {value = var.bucket_name_tfstate_prod}
output "bucket_name_tfstate_nonprod" {value = var.bucket_name_tfstate_nonprod}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

variable "bucket_name_tfstate_dev" {
  description = "Name of tfstate bucket for dev projects."
  type        = string
  default     = "tfstate-dev-usfs-tf-admin"
}

variable "bucket_name_tfstate_prod" {
  description = "Name of tfstate bucket for production applications."
  type        = string
  default     = "usfs-prod-tf-state"
}

variable "bucket_name_tfstate_nonprod" {
  description = "Name of tfstate bucket for non-prod projects."
  type        = string
  default     = "tfstate-nonprod-usfs-tf-admin"
}

output "admin_shared_email" {value = var.admin_shared_email}
output "gtac_shared_email" {value = var.gtac_shared_email}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

variable "admin_shared_email" {
  description = "Admin shared email."
  type        = string
  default     = "SM.FS.R9AtlasAlert@usda.gov"
}

variable "gtac_shared_email" {
  description = "GTAC shared email."
  type        = string
  default     = "nathan.pugh@usda.gov"
}
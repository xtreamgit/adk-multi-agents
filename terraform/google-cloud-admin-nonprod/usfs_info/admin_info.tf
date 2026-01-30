
# Admin outputs
output "admin_email_list"                 {value = var.admin_email_list}
output "admin_group_id"                   {value = var.admin_group_id}
output "admin_logging_project_id"         {value = var.admin_logging_project_id}
output "admin_project_folder"             {value = var.admin_project_folder}
output "admin_project_id"                 {value = var.admin_project_id}
output "admin_project_name"               {value = var.admin_project_name}
output "admin_security_viewer_group_id"   {value = var.admin_security_viewer_group_id}
# Folders
output "admin_usfs_folder_id"             {value = var.admin_usfs_folder_id}
output "admin_cio_folder_id"              {value = var.admin_cio_folder_id}
# Groups
output "admin_viewer_group_id"            {value = var.admin_viewer_group_id}
output "admin_cio_tf_dev_group_id"        {value = var.admin_cio_tf_dev_group_id}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

variable "admin_email_list" {
  description = "Admin email list."
  type        = list(string)
  default     = [
    "carlos.ramirez2@usda.gov",
    "andrew.stratton@usda.gov"
  ]
}

variable "admin_group_id" {
  description = "GCP admin group ID."
  type        = string
  default     = "group:usfs-gcp-admin@usda.gov"
}

variable "admin_logging_project_id" {
  description = "The admin logging project ID"
  type        = string
  default     = "usfs-tf-admin-logging"
}

variable "admin_project_folder" {
  description = "Parent folder ID for the usfs-tf-admin project.  Has to be formatted as 'folders/12345678'"
  type        = string
  default     = "folders/593854176251"
  validation {
    condition     = var.admin_project_folder == null || can(regex("^folders/[0-9]+", var.admin_project_folder))
    error_message = "Projects exist within a parent folder, not directly underneath the organization node.  The format also has to be 'folders/FOLDER_ID'."
  }
}

variable "admin_project_id" {
  description = "The admin project ID"
  type        = string
  default     = "usfs-tf-admin"
}

variable "admin_project_name" {
  description = "The admin project name"
  type        = string
  default     = "usfs-tf-admin"
}

variable "admin_security_viewer_group_id" {
  description = "Admin security viewer group ID."
  type        = string
  default     = "group:AFS-CIO-Cyber@usda.gov"
}

# Folders
variable "admin_usfs_folder_id" {
  description = "Admin USFS folder ID."
  type        = string
  default     = "folders/814734598579"
}

variable "admin_cio_folder_id" {
  description = "Admin CIO folder ID."
  type        = string
  default     = "folders/84203078144"
}


# Groups
variable "admin_viewer_group_id" {
  description = "GCP admin viewer group ID."
  type        = string
  default     = "group:usfs-gcp-admin-viewonly@usda.gov"
}

variable "admin_cio_tf_dev_group_id" {
  description = "Admin CIO folder terraform developer group ID."
  type        = string
  default     = "group:usfs-cio-terraform-developers@usda.gov"
}

# common variables
variable "common" {
    type = object({
      # Project information
      project_id                      = string
      project_name                    = string
      project_region                  = string
      project_backup_region           = string
    })
}

# bucket information variables
variable "bucket_info" {
    type = object({
      bucket_apply_life_cycle_rules    = bool
      bucket_create_backup             = bool
      bucket_force_destroy             = bool
      bucket_name_list                 = list(string)
      bucket_public_access_prevention  = string
      bucket_soft_delete_seconds       = number
      bucket_versioning                = bool
    })
}

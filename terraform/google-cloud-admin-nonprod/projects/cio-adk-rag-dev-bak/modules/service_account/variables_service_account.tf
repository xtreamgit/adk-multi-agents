
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
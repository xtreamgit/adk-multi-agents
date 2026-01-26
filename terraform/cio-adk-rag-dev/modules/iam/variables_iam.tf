
# usfs info
module "usfs_info" {
  source = "../../../../usfs_info"
}

# usfs custom roles
module "usfs_custom_roles" {
  source = "../../../../usfs_custom_roles"
}

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

# project iam binding
variable "iam_binding_expiration" {
  type = object({
    title       = string
    description = string
    timestamp   = string
  })
}

# project permissions map
variable "project_permissions_map" {
  type = map(object({
    email_list     = list(string)
    cust_role_list = list(string)
    gcp_role_list  = list(string)
  }))
  # default = {}
}
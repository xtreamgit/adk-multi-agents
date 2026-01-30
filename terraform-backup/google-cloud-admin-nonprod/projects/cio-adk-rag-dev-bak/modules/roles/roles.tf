
# Create role list from project permissions map
locals {
  roles_list = distinct(flatten([
    for user_type, info in var.project_permissions_map : [
      for role in info.cust_role_list : {
        role = role
      }
    ]
  ]))
}

# Create custom roles from map
resource "google_project_iam_custom_role" "role" {
  # for_each    = var.roles_list
  for_each    = { for entry in local.roles_list: "${entry.role}" => entry }
  project     = var.common.project_id
  stage       = "BETA"

  role_id     = module.usfs_custom_roles[each.value.role].name
  title       = module.usfs_custom_roles[each.value.role].disp_name
  description = module.usfs_custom_roles[each.value.role].desc
  permissions = module.usfs_custom_roles[each.value.role].perms
}

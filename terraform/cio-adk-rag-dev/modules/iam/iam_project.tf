
# https://stackoverflow.com/questions/76765785/adding-multiple-roles-to-a-gcp-group-in-multiple-projects-through-terraform

# Create outputs to view view terraform console
output "custom_role_list" {value = local.custom_role_list}
output "custom_role_member_list" {value = local.custom_role_member_list}

output "gcp_role_list" {value = local.gcp_role_list}
output "gcp_role_member_list" {value = local.gcp_role_member_list}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Create local user and role combinations list from project permissions map
locals {

  # Custom roles handling, get unique list of custom roles
  custom_role_list = distinct(flatten([ for user in var.project_permissions_map : user.cust_role_list]))
  # Get role members for each custom role
  custom_role_member_list = tolist([ for role in local.custom_role_list: {
    "role":         role
    "email_list":   tolist(flatten([ for user in var.project_permissions_map : [
      for custom_role in user.cust_role_list : user.email_list if custom_role == role
    ]]))
  }])

  # GCP roles handling, get unique list of gcp roles
  gcp_role_list = distinct(flatten([ for user in var.project_permissions_map : user.gcp_role_list]))
  # Get role members for each gcp role
  gcp_role_member_list = tolist([ for role in local.gcp_role_list: {
    "role":         role
    "email_list":   tolist(flatten([ for user in var.project_permissions_map : [
      for gcp_role in user.gcp_role_list : user.email_list if gcp_role == role
    ]]))
  }])
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Use custom_role_member_list to assign custom role project permissions
resource "google_project_iam_binding" "project_custom_role_iam_bindings" {
  for_each = { for entry in local.custom_role_member_list: "${entry.role}.$tostring({entry.email_list})" => entry }
  project = var.common.project_id
  role = "projects/${var.common.project_id}/roles/${module.usfs_custom_roles[each.value.role].name}"
  members = each.value.email_list

  dynamic "condition" {
    for_each = var.iam_binding_expiration == null ? [] : [1]
    content {
      title       = var.iam_binding_expiration.title
      description = var.iam_binding_expiration.description
      expression  = "request.time < timestamp(\"${var.iam_binding_expiration.timestamp}\")"
    }
  }
}

# Use gcp_role_member_list to assign pre-defined gcp role project permissions
resource "google_project_iam_binding" "project_gcp_role_iam_bindings" {
  for_each = { for entry in local.gcp_role_member_list: "${entry.role}.$tostring{entry.email_list}" => entry }
  project = var.common.project_id
  role = each.value.role
  members = each.value.email_list

  dynamic "condition" {
    for_each = var.iam_binding_expiration == null ? [] : [1]
    content {
      title       = var.iam_binding_expiration.title
      description = var.iam_binding_expiration.description
      expression  = "request.time < timestamp(\"${var.iam_binding_expiration.timestamp}\")"
    }
  }
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

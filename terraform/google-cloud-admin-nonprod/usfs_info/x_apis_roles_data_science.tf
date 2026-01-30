
# To get list of permissions for an existing role, use:
# gcloud iam roles describe roles/<role.name>

# # Project apis outputs
# output "apis_data_science_project" {value = var.apis_data_science_project}

# # Project user role outputs
# output "cust_role_data_science_user_name" {value = var.cust_role_data_science_user_name}
# output "cust_role_data_science_user_disp_name" {value = var.cust_role_data_science_user_disp_name}
# output "cust_role_data_science_user_desc" {value = var.cust_role_data_science_user_desc}
# output "cust_role_data_science_user_perms" {value = var.cust_role_data_science_user_perms}

# # Project user addon role outputs (if needed)
# output "cust_role_data_science_addon_name" {value = var.cust_role_data_science_addon_name}
# output "cust_role_data_science_addon_disp_name" {value = var.cust_role_data_science_addon_disp_name}
# output "cust_role_data_science_addon_desc" {value = var.cust_role_data_science_addon_desc}
# output "cust_role_data_science_addon_perms" {value = var.cust_role_data_science_addon_perms}

# # Project viewer role outputs (if needed)
# output "cust_role_data_science_viewer_name" {value = var.cust_role_data_science_viewer_name}
# output "cust_role_data_science_viewer_disp_name" {value = var.cust_role_data_science_viewer_disp_name}
# output "cust_role_data_science_viewer_desc" {value = var.cust_role_data_science_viewer_desc}
# output "cust_role_data_science_viewer_perms" {value = var.cust_role_data_science_viewer_perms}

# #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# # api list for project (needs to be updated for data science)
# variable "apis_data_science_project" {
#   description = "APIs for a Data Science project."
#   type        = list(string)
#   default     = [
#     # Project APIs




#     # Standard Type APIs
#     "cloudresourcemanager.googleapis.com",
#     "logging.googleapis.com",
#     "monitoring.googleapis.com",
#     "oslogin.googleapis.com",
#     "privilegedaccessmanager.googleapis.com",
#     "storage-api.googleapis.com",
#     "storage-component.googleapis.com",
#     "storage.googleapis.com",
#     "websecurityscanner.googleapis.com",
#   ]
# }

# #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# # Custom role: user role
# variable "cust_role_data_science_user_name" {
#   description = "Name of Data Science user role."
#   type        = string
#   default     = "USFSDataScienceUser"
# }

# variable "cust_role_data_science_user_disp_name" {
#   description = "Display name of Data Science user role."
#   type        = string
#   default     = "USFS Data Science User"
# }

# variable "cust_role_data_science_user_desc" {
#   description = "Description of Data Science user role."
#   type        = string
#   default     = "USFS Data Science user role."
# }

# # needs to be updated for data science
# variable "cust_role_data_science_user_perms" {
#   description = "List of Data Science user role permissions."
#   type        = list(string)
#   default     = [
#     # gcloud iam roles describe roles/<role.name>


#     # Custom additional permissions


#     # # gcloud iam roles describe roles/iam.serviceAccountUser
#     # "iam.serviceAccounts.actAs",
#     # "iam.serviceAccounts.get",
#     # "iam.serviceAccounts.list",
#     # # "resourcemanager.projects.get",           # already included
#     # # "resourcemanager.projects.list",          # n/a a project level
    
#     # # gcloud iam roles describe roles/serviceusage.serviceUsageConsumer
#     # "monitoring.timeSeries.list",
#     # "serviceusage.quotas.get",
#     # "serviceusage.services.get",
#     # "serviceusage.services.list",
#     # "serviceusage.services.use",

#     # Custom storage user permissions
#     "orgpolicy.policy.get",
#     "storage.buckets.get",
#     "storage.buckets.getIamPolicy",
#     "storage.buckets.getObjectInsights",
#     "storage.buckets.list",
#     "storage.buckets.listEffectiveTags",
#     "storage.buckets.listTagBindings",
#     "storage.multipartUploads.abort",
#     "storage.multipartUploads.create",
#     "storage.multipartUploads.list",
#     "storage.multipartUploads.listParts",
#     "storage.objects.create",
#     "storage.objects.delete",
#     "storage.objects.get",
#     "storage.objects.getIamPolicy",
#     "storage.objects.list",
#     "storage.objects.update",
#   ]
# }

# #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# # Custom role: user add-on role
# variable "cust_role_data_science_addon_name" {
#   description = "Name of Data Science Add-on role."
#   type        = string
#   default     = "USFSDataScienceAddOn"
# }

# variable "cust_role_data_science_addon_disp_name" {
#   description = "Display name of Data Science Add-on role."
#   type        = string
#   default     = "USFS Data Science Add-on"
# }

# variable "cust_role_data_science_addon_desc" {
#   description = "Description of Data Science Add-on role."
#   type        = string
#   default     = "USFS Data Science Add-on role. Role assumes user is already a user role member."
# }

# variable "cust_role_data_science_addon_perms" {
#   description = "List of Data Science Add-on role permissions."
#   type        = list(string)
#   default     = null
#   # default     = [
#   #   # Note: role adds functionality to user role. User must also be member of user role.
#   #   # User add-on permissions
#   # ]
# }

# #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# # Custom role: viewer
# variable "cust_role_data_science_viewer_name" {
#   description = "Name of Data Science viewer role."
#   type        = string
#   default     = "USFSDataScienceViewer"
# }

# variable "cust_role_data_science_viewer_disp_name" {
#   description = "Display name of Data Science viewer role."
#   type        = string
#   default     = "USFS Data Science Viewer"
# }

# variable "cust_role_data_science_viewer_desc" {
#   description = "Description of Data Science viewer role."
#   type        = string
#   default     = "USFS Data Science viewer role."
# }

# variable "cust_role_data_science_viewer_perms" {
#   description = "List of Data Science viewer role permissions."
#   type        = list(string)
#   default     = null
#   # default     = [
#   #   # Viewer permissions
#   # ]
# }

# To get list of permissions for an existing role, use:
# gcloud iam roles describe roles/<role.name>
# Note: setup of roles needs to include three roles:
#       1) user role
#       2) additional permissions role (set perms to null if not needed)
#       3) viewer role (set perms to null if not needed)

# Replacement text:
# 1. projectType, project type, i.e. ee or vertexai_colab
# 2. projectDesc, descriptive project type, i.e. Vertex AI - Colab or Earth Engine
# 3. <roleProjectType>, no underscore/dash user role, i.e. VertexAIColab
# 4. useraddon, (optional) update add-on role variable name, i.e. scheduler or appPublisher
# 5. AddOn, (optional) udate add-one role name, i.e. Scheduler, or AppPublisher
# 4. user add-on, can replace add-on role description text, i.e. scheduler or app publisher


# # Project apis outputs
# output "apis_ee_colab_project" {value = var.apis_ee_colab_project}

# # Project user role outputs
# output "cust_role_ee_colab_user_name" {value = var.cust_role_ee_colab_user_name}
# output "cust_role_ee_colab_user_disp_name" {value = var.cust_role_ee_colab_user_disp_name}
# output "cust_role_ee_colab_user_desc" {value = var.cust_role_ee_colab_user_desc}
# output "cust_role_ee_colab_user_perms" {value = concat(
#   var.cust_role_ee_colab_user_perms,
#   var.perms_ee_user,
#   var.perms_serviceaccountuser,
#   var.perms_serviceusageconsumer,
#   var.perms_storage_user,
#   )}

# # Project user addon role outputs (if needed)
# output "cust_role_ee_colab_useraddon_name" {value = var.cust_role_ee_colab_useraddon_name}
# output "cust_role_ee_colab_useraddon_disp_name" {value = var.cust_role_ee_colab_useraddon_disp_name}
# output "cust_role_ee_colab_useraddon_desc" {value = var.cust_role_ee_colab_useraddon_desc}
# output "cust_role_ee_colab_useraddon_perms" {value = concat(
#   var.cust_role_ee_colab_useraddon_perms,
#   )}

# # Project viewer role outputs (if needed)
# output "cust_role_ee_colab_viewer_name" {value = var.cust_role_ee_colab_viewer_name}
# output "cust_role_ee_colab_viewer_disp_name" {value = var.cust_role_ee_colab_viewer_disp_name}
# output "cust_role_ee_colab_viewer_desc" {value = var.cust_role_ee_colab_viewer_desc}
# output "cust_role_ee_colab_viewer_perms" {value = concat(
#   var.cust_role_ee_colab_viewer_perms,
#   )}

# #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# # api list for project
# variable "apis_ee_colab_project" {
#   description = "APIs for a Earth Engine Colab project."
#   type        = list(string)
#   default     = [
#     # Project APIs
#     # Earth Engine Project APIs
#     "compute.googleapis.com",                   #
#     "earthengine.googleapis.com",               #
    
#     # Vertex AI-Colab Project APIs
#     # "accesscontextmanager.googleapis.com",     # lack permissions to use
#     "aiplatform.googleapis.com",
#     "compute.googleapis.com",
#     "dataform.googleapis.com",
#     "dns.googleapis.com",                        # needed to enable DNS logging
#     "generativelanguage.googleapis.com",
#     "networkconnectivity.googleapis.com",        # runtime troubleshooting add-on, may not be needed
#     "notebooks.googleapis.com",
#     "secretmanager.googleapis.com",
#     "servicenetworking.googleapis.com",          # needed for service network
#     "visionai.googleapis.com",

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

# # Custom role: EE Colab User
# variable "cust_role_ee_colab_user_name" {
#   description = "Name of Earth Engine Colab user role."
#   type        = string
#   default     = "USFSEEColabUser"
# }

# variable "cust_role_ee_colab_user_disp_name" {
#   description = "Display name of Earth Engine Colab user role."
#   type        = string
#   default     = "USFS Earth Engine Colab User"
# }

# variable "cust_role_ee_colab_user_desc" {
#   description = "Description of Earth Engine Colab user role."
#   type        = string
#   default     = "USFS Earth Engine Colab user role."
# }

# variable "cust_role_ee_colab_user_perms" {
#   description = "List of Earth Engine Colab user role permissions."
#   type        = list(string)
#   default     = [
#     # gcloud iam roles describe roles/<role.name>

#     # Colab roles
#     # gcloud iam roles describe roles/aiplatform.colabEnterpriseUser
#     "aiplatform.notebookExecutionJobs.create",
#     "aiplatform.notebookExecutionJobs.delete",
#     "aiplatform.notebookExecutionJobs.get",
#     "aiplatform.notebookExecutionJobs.list",
#     "aiplatform.notebookRuntimeTemplates.apply",
#     "aiplatform.notebookRuntimeTemplates.get",
#     "aiplatform.notebookRuntimeTemplates.getIamPolicy",
#     "aiplatform.notebookRuntimeTemplates.list",
#     "aiplatform.notebookRuntimes.assign",
#     "aiplatform.notebookRuntimes.get",
#     "aiplatform.notebookRuntimes.list",
#     "aiplatform.operations.list",
#     "aiplatform.pipelineJobs.create",
#     # "aiplatform.schedules.create",            # scheduling added to scheduler role
#     # "aiplatform.schedules.delete",
#     # "aiplatform.schedules.get",
#     # "aiplatform.schedules.list",
#     # "aiplatform.schedules.update",
#     "dataform.locations.get",
#     "dataform.locations.list",
#     "dataform.repositories.create",
#     "dataform.repositories.list",
#     "resourcemanager.projects.get",
#     # "resourcemanager.projects.list",          # n/a at project level

#     # Custom additional Vertex AI permissions
#     "aiplatform.endpoints.predict",             # added 6/10/24, need reason to keep
#     "dataform.repositories.get",                # allows users access to all repositories in project
#     "resourcemanager.projects.createBillingAssignment", # need reason to keep

#     # gcloud iam roles describe roles/visionai.analysisViewer
#     "visionai.analyses.get",
#     "visionai.analyses.list",

#     # # gcloud iam roles describe roles/visionai.eventViewer
#     # "visionai.events.get",
#     # "visionai.events.list",

#     # gcloud iam roles describe roles/visionai.operatorViewer
#     "visionai.operators.get",
#     "visionai.operators.list",

#   ]
# }

# #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# # Custom role: user add-on role
# variable "cust_role_ee_colab_useraddon_name" {
#   description = "Name of Earth Engine Colab user add-on role."
#   type        = string
#   default     = "USFSEEColabAddOn"
# }

# variable "cust_role_ee_colab_useraddon_disp_name" {
#   description = "Display name of Earth Engine Colab user add-on role."
#   type        = string
#   default     = "USFS Earth Engine Colab user add-on"
# }

# variable "cust_role_ee_colab_useraddon_desc" {
#   description = "Description of Earth Engine Colab user add-on role."
#   type        = string
#   default     = "USFS Earth Engine Colab user add-on role. Role assumes user is already a user role member."
# }

# variable "cust_role_ee_colab_useraddon_perms" {
#   description = "List of Earth Engine Colab user add-on role permissions."
#   type        = list(string)
#   default     = []
#   # default     = [
#   #   # Note: role adds functionality to user role. User must also be member of user role.
#   #   # User add-on permissions
#   # ]
# }

# #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# # Custom role: viewer
# variable "cust_role_ee_colab_viewer_name" {
#   description = "Name of Earth Engine Colab viewer role."
#   type        = string
#   default     = "USFSEEColabViewer"
# }

# variable "cust_role_ee_colab_viewer_disp_name" {
#   description = "Display name of Earth Engine Colab viewer role."
#   type        = string
#   default     = "USFS Earth Engine Colab Viewer"
# }

# variable "cust_role_ee_colab_viewer_desc" {
#   description = "Description of Earth Engine Colab viewer role."
#   type        = string
#   default     = "USFS Earth Engine Colab viewer role."
# }

# variable "cust_role_ee_colab_viewer_perms" {
#   description = "List of Earth Engine Colab viewer role permissions."
#   type        = list(string)
#   default     = []
#   # default     = [
#   #   # Viewer permissions
#   # ]
# }
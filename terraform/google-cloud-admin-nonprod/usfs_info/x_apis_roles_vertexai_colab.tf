
# To get list of permissions for an existing role, use:
# gcloud iam roles describe roles/<role.name>

# # Vertex AI - Colab project apis outputs
# output "apis_vertexai_colab_project" {value = var.apis_vertexai_colab_project}

# # Vertex AI - Colab project user role outputs
# output "cust_role_vertexai_colab_user_name" {value = var.cust_role_vertexai_colab_user_name}
# output "cust_role_vertexai_colab_user_disp_name" {value = var.cust_role_vertexai_colab_user_disp_name}
# output "cust_role_vertexai_colab_user_desc" {value = var.cust_role_vertexai_colab_user_desc}
# output "cust_role_vertexai_colab_user_perms" {value = concat(
#   var.cust_role_vertexai_colab_user_perms,
#   var.perms_dataform_code_viewer,
#   var.perms_serviceaccountuser,
#   var.perms_serviceusageconsumer,
#   var.perms_storage_user,
#   )}

# # Vertex AI - Colab project scheduler role outputs
# output "cust_role_vertexai_colab_scheduler_name" {value = var.cust_role_vertexai_colab_scheduler_name}
# output "cust_role_vertexai_colab_scheduler_disp_name" {value = var.cust_role_vertexai_colab_scheduler_disp_name}
# output "cust_role_vertexai_colab_scheduler_desc" {value = var.cust_role_vertexai_colab_scheduler_desc}
# output "cust_role_vertexai_colab_scheduler_perms" {value = concat(
#   var.cust_role_vertexai_colab_scheduler_perms,
#   )}

# # Vertex AI - Colab project viewer role outputs (is viewer role needed?)
# output "cust_role_vertexai_colab_viewer_name" {value = var.cust_role_vertexai_colab_viewer_name}
# output "cust_role_vertexai_colab_viewer_disp_name" {value = var.cust_role_vertexai_colab_viewer_disp_name}
# output "cust_role_vertexai_colab_viewer_desc" {value = var.cust_role_vertexai_colab_viewer_desc}
# output "cust_role_vertexai_colab_viewer_perms" {value = concat(
#   var.cust_role_vertexai_colab_viewer_perms,
#   )}

# #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# # api list for vertex-ai colab project
# variable "apis_vertexai_colab_project" {
#   description = "APIs for a Vertex AI - Colab project."
#   type        = list(string)
#   default     = [
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
#     "securitycenter.googleapis.com",
#     "securitycentermanagement.googleapis.com",
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

# # Custom role: VertexAI-Colab user
# variable "cust_role_vertexai_colab_user_name" {
#   description = "Name of Vertex AI-Colab user role."
#   type        = string
#   default     = "USFSVertexAIColabUser"
# }

# variable "cust_role_vertexai_colab_user_disp_name" {
#   description = "Display name of Vertex AI-Colab user role."
#   type        = string
#   default     = "USFS VertexAI-Colab User"
# }

# variable "cust_role_vertexai_colab_user_desc" {
#   description = "Description of Vertex AI-Colab user role."
#   type        = string
#   default     = "USFS Vertex AI-Colab user role."
# }

# variable "cust_role_vertexai_colab_user_perms" {
#   description = "List of Vertex AI-Colab user role permissions."
#   type        = list(string)
#   default     = [
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

# # Custom role: VertexAI-Colab scheduler
# variable "cust_role_vertexai_colab_scheduler_name" {
#   description = "Name of Vertex AI-Colab scheduler role."
#   type        = string
#   default     = "USFSVertexAIColabScheduler"
# }

# variable "cust_role_vertexai_colab_scheduler_disp_name" {
#   description = "Display name of Vertex AI-Colab scheduler role."
#   type        = string
#   default     = "USFS VertexAI-Colab Scheduler"
# }

# variable "cust_role_vertexai_colab_scheduler_desc" {
#   description = "Description of Vertex AI-Colab scheduler role."
#   type        = string
#   default     = "USFS Vertex AI-Colab scheduler role. Role assumes user is already a user role member."
# }

# variable "cust_role_vertexai_colab_scheduler_perms" {
#   description = "List of Vertex AI-Colab scheduler role permissions."
#   type        = list(string)
#   default     = [
#     # Note: role adds functionality to vertexai-colab user role. User must also be member of user role.
#     # Scheduler permissions
#     "aiplatform.schedules.create",
#     "aiplatform.schedules.delete",
#     "aiplatform.schedules.get",
#     "aiplatform.schedules.list",
#     "aiplatform.schedules.update",

#     # Delete runtime permission
#     "aiplatform.notebookRuntimes.delete",
#   ]
# }

# #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# # Viewer role not needed for a VertexAI-Colab project, 

# # Custom role: VertexAI-Colab viewer
# variable "cust_role_vertexai_colab_viewer_name" {
#   description = "Name of Vertex AI-Colab viewer role."
#   type        = string
#   default     = "USFSVertexAIColabViewer"
# }

# variable "cust_role_vertexai_colab_viewer_disp_name" {
#   description = "Display name of Vertex AI-Colab viewer role."
#   type        = string
#   default     = "USFS VertexAI-Colab Viewer"
# }

# variable "cust_role_vertexai_colab_viewer_desc" {
#   description = "Description of Vertex AI-Colab viewer role."
#   type        = string
#   default     = "USFS Vertex AI-Colab viewer role."
# }

# variable "cust_role_vertexai_colab_viewer_perms" {
#   description = "List of Vertex AI-Colab viewer role permissions."
#   type        = list(string)
#   default     = []
# }
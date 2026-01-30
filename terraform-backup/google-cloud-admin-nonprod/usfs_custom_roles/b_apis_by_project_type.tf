
# APIs for project types

# Included: 
# apis_admin_arch_test_project - Admin Architechture Testing
# apis_billing_project - Billing (BigQuery)
# apis_chatbot_build_project - Chatbot Build (VertexAI, Cloud Run, Cloud Build)
# apis_ee_project - EE (EarthEngine)
# apis_ee_bq_colab_project - EarthEngine, BigQuery, Colab
# apis_landis_project - Landis
# apis_rag_project - Rag/Graph Rag
# apis_vertexai_colab_project - Vertex AI-Colab (VertexAI, Colab Enterprise)
# apis_vertexai_project - Vertex AI
# apis_vertexai_workbench_project - Vertex AI-Workbench (VertexAI, Colab Enterprise, Workbench, BigQuery)

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Empty api list for project template
output "blank_api_listing" {value = []}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Admin Architechture Testing project APIs
output "apis_admin_arch_test_project" {value = var.apis_admin_arch_test_project}

variable "apis_admin_arch_test_project" {
  description = "APIs for a Admin Architecture Testing project."
  type        = list(string)
  default     = [
    # Project APIs
    "alloydb.googleapis.com",
    "apigee.googleapis.com",
    "bigquery.googleapis.com",
    "cloudaicompanion.googleapis.com",
    "cloudkms.googleapis.com",
    "composer.googleapis.com",
    "compute.googleapis.com",
    "dataflow.googleapis.com",
    "dlp.googleapis.com",
    "iam.googleapis.com",
    "oslogin.googleapis.com",
    "privilegedaccessmanager.googleapis.com",
    "pubsub.googleapis.com",
    "run.googleapis.com",
    "sqladmin.googleapis.com",
    "sql-component.googleapis.com",
    
    # Monitoring Type APIs
    "dns.googleapis.com",                        # needed to enable DNS logging
    "firewallinsights.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "securitycenter.googleapis.com",
    "securitycentermanagement.googleapis.com",
    "websecurityscanner.googleapis.com",

    # Standard Type APIs
    "cloudresourcemanager.googleapis.com",
    "storage-api.googleapis.com",
    "storage-component.googleapis.com",
    "storage.googleapis.com",
  ]
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Billing project APIs
output "apis_billing_project" {value = var.apis_billing_project}

variable "apis_billing_project" {
  description = "APIs for a Billing project."
  type        = list(string)
  default     = [
    # Project APIs
    "bigqueryconnection.googleapis.com",
    "bigquerydatatransfer.googleapis.com",
    "cloudapis.googleapis.com",
    "compute.googleapis.com",
    "connectors.googleapis.com",
    "dataform.googleapis.com",
    "dataplex.googleapis.com",
    "secretmanager.googleapis.com",
 
    # Monitoring Type APIs
    "dns.googleapis.com",                        # needed to enable DNS logging
    "firewallinsights.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "securitycenter.googleapis.com",
    "securitycentermanagement.googleapis.com",
    "websecurityscanner.googleapis.com",

    # Standard Type APIs
    "cloudresourcemanager.googleapis.com",
    "privilegedaccessmanager.googleapis.com",
    "storage-api.googleapis.com",
    "storage-component.googleapis.com",
    "storage.googleapis.com",
  ]
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Chatbot Building APIs
output "apis_chatbot_build_project" {value = var.apis_chatbot_build_project}

variable "apis_chatbot_build_project" {
  description = "APIs for Chatbot Build project."
  type        = list(string)
  default     = [
    # Project APIs
    "aiplatform.googleapis.com",              # Vertex AI API
    "artifactregistry.googleapis.com",        # Artifact Registry API
    "cloudbuild.googleapis.com",              # Cloud Build API
    "compute.googleapis.com",                 # Compute Engine API
    "containerscanning.googleapis.com",       # Container Scanning API 
    "config.googleapis.com",                  # Infrastructure Manager API
    "dialogflow.googleapis.com",              # Dialogflow API
    "discoveryengine.googleapis.com",         # Discovery Engine API
    "iap.googleapis.com",                     # Identity-Aware Proxy API
    "networkconnectivity.googleapis.com",     # Network Connectivity API
    "networksecurity.googleapis.com",         # Network Security API
    "oslogin.googleapis.com",                 # OS Login API
    "privilegedaccessmanager.googleapis.com", # Privileged Access Manager API
    "run.googleapis.com",                     # Cloud Run Admin API
    "runapps.googleapis.com",                 # Serverless Integrations API
    "secretmanager.googleapis.com",           # Secret Manager API
    "servicenetworking.googleapis.com",       # Service Networking API
    "vpcaccess.googleapis.com",               # Serverless VPC Access API

    # Gemini Cloud/Code Assist APIs
    "geminicloudassist.googleapis.com",
    "cloudaicompanion.googleapis.com",
    "monitoring.googleapis.com",
    "cloudasset.googleapis.com",
    "recommender.googleapis.com",
    "appoptimize.googleapis.com",

    # Monitoring Type APIs
    "dns.googleapis.com",                        # needed to enable DNS logging
    "firewallinsights.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "securitycenter.googleapis.com",
    "securitycentermanagement.googleapis.com",
    "websecurityscanner.googleapis.com",

    # Standard Type APIs
    "cloudresourcemanager.googleapis.com",
    "storage-api.googleapis.com",
    "storage-component.googleapis.com",
    "storage.googleapis.com",
  ]
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# EE project APIs
output "apis_ee_project" {value = var.apis_ee_project}

variable "apis_ee_project" {
  description = "APIs for Earth Engine project."
  type        = list(string)
  default     = [
    # Project APIs
    "earthengine.googleapis.com",

    # Monitoring Type APIs
    # "dns.googleapis.com",                       # no VPC for basic EE project
    # "firewallinsights.googleapis.com",          # no VPC for basic EE project
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "securitycenter.googleapis.com",
    "securitycentermanagement.googleapis.com",
    "websecurityscanner.googleapis.com",

    # Standard Type APIs
    "cloudresourcemanager.googleapis.com",
    "storage-api.googleapis.com",
    "storage-component.googleapis.com",
    "storage.googleapis.com",
  ]
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# EE project APIs
output "apis_ee_bq_colab_project" {value = var.apis_ee_bq_colab_project}

variable "apis_ee_bq_colab_project" {
  description = "APIs for Earth Engine project."
  type        = list(string)
  default     = [
    # Project APIs
    "aiplatform.googleapis.com",
    "bigquery.googleapis.com",
    "bigquerystorage.googleapis.com",
    "cloudaicompanion.googleapis.com",
    "compute.googleapis.com",
    "dataform.googleapis.com",
    "earthengine.googleapis.com",                # Earth Engine API
    "networkconnectivity.googleapis.com",        # runtime troubleshooting add-on, may not be needed
    "notebooks.googleapis.com",
    "oslogin.googleapis.com",
    "privilegedaccessmanager.googleapis.com",
    "secretmanager.googleapis.com",
    "servicenetworking.googleapis.com",          # needed for service network
    "visionai.googleapis.com",

    # Monitoring Type APIs
    "dns.googleapis.com",                        # needed to enable DNS logging
    "firewallinsights.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "securitycenter.googleapis.com",
    "securitycentermanagement.googleapis.com",
    "websecurityscanner.googleapis.com",

    # Standard Type APIs
    "cloudresourcemanager.googleapis.com",
    "storage-api.googleapis.com",
    "storage-component.googleapis.com",
    "storage.googleapis.com",
  ]
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Landis project APIs
output "apis_landis_project" {value = var.apis_landis_project}

variable "apis_landis_project" {
  description = "APIs for Earth Engine project."
  type        = list(string)
  default     = [
    # Project APIs
    # "accesscontextmanager.googleapis.com",     # lack permissions to use
    "compute.googleapis.com",
    "firewallinsights.googleapis.com",           # view firewall insights
    "networkmanagement.googleapis.com",          # view network performace dashboard
    "networkconnectivity.googleapis.com",        # runtime troubleshooting add-on, may not be needed
    "osconfig.googleapis.com",                   # ensures smooth installation and maintenance of the ops agent
    "oslogin.googleapis.com",
    "privilegedaccessmanager.googleapis.com",
    "secretmanager.googleapis.com",
    "servicenetworking.googleapis.com",          # needed for service network
    
    # Monitoring Type APIs
    "dns.googleapis.com",                        # needed to enable DNS logging
    "firewallinsights.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    # "networksecurity.googleapis.com",
    "securitycenter.googleapis.com",
    "securitycentermanagement.googleapis.com",
    "websecurityscanner.googleapis.com",

    # Standard Type APIs
    "cloudresourcemanager.googleapis.com",
    "storage-api.googleapis.com",
    "storage-component.googleapis.com",
    "storage.googleapis.com",
  ]
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Rag/Graph Rag APIs
output "apis_rag_project" {value = var.apis_rag_project}

variable "apis_rag_project" {
  description = "APIs for Rag/Graph Rag project."
  type        = list(string)
  default     = [
    # Project APIs
    # "accesscontextmanager.googleapis.com",     # lack permissions to use
    "aiplatform.googleapis.com",
    "cloudaicompanion.googleapis.com",
    "compute.googleapis.com",
    "dataform.googleapis.com",
    "networkconnectivity.googleapis.com",        # runtime troubleshooting add-on, may not be needed
    "notebooks.googleapis.com",
    "oslogin.googleapis.com",                    # for VM login
    "privilegedaccessmanager.googleapis.com",
    "secretmanager.googleapis.com",
    "servicenetworking.googleapis.com",          # needed for service network
    "visionai.googleapis.com",

    # BigQuery APIs
    "bigquery.googleapis.com",
    "bigquerystorage.googleapis.com",

    # Monitoring Type APIs
    "dns.googleapis.com",                        # needed to enable DNS logging
    "firewallinsights.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "securitycenter.googleapis.com",
    "securitycentermanagement.googleapis.com",
    "websecurityscanner.googleapis.com",

    # Standard Type APIs
    "cloudresourcemanager.googleapis.com",
    "storage-api.googleapis.com",
    "storage-component.googleapis.com",
    "storage.googleapis.com",

    # Added project APIs
    "artifactregistry.googleapis.com",        # Artifact Registry API
    "cloudapis.googleapis.com",
    "cloudbuild.googleapis.com",              # Cloud Build API
    "cloudaicompanion.googleapis.com",
    "cloudidentity.googleapis.com",           # Cloud Identity API - for IAM management
    "config.googleapis.com",
    "containerscanning.googleapis.com",       # Container Scanning API
    "discoveryengine.googleapis.com", 
    "dlp.googleapis.com",
    "documentai.googleapis.com",
    "eventarc.googleapis.com",
    "eventarcpublishing.googleapis.com",
    "generativelanguage.googleapis.com",
    "iam.googleapis.com",
    "iap.googleapis.com",                     # Identity-Aware Proxy API - CRITICAL for frontend auth
    "modelarmor.googleapis.com",              # Model Armor API - for AI model protection
    "run.googleapis.com",                     # Cloud Run Admin API
    "runapps.googleapis.com",                 # Serverless Integrations API
    "serviceusage.googleapis.com",
    "spanner.googleapis.com",
    "sqladmin.googleapis.com",
    "vpcaccess.googleapis.com",               # Serverless VPC Access API
    "workflows.googleapis.com",
  ]
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# VertexAI Colab Enterprise APIs
output "apis_vertexai_colab_project" {value = var.apis_vertexai_colab_project}

variable "apis_vertexai_colab_project" {
  description = "APIs for Vertex AI-Colab Enterprise project."
  type        = list(string)
  default     = [
    # Project APIs
    # "accesscontextmanager.googleapis.com",     # lack permissions to use
    "aiplatform.googleapis.com",
    "compute.googleapis.com",
    "dataform.googleapis.com",
    "networkconnectivity.googleapis.com",        # runtime troubleshooting add-on, may not be needed
    "notebooks.googleapis.com",
    "oslogin.googleapis.com",
    "privilegedaccessmanager.googleapis.com",
    "secretmanager.googleapis.com",
    "servicenetworking.googleapis.com",          # needed for service network
    "visionai.googleapis.com",

    # Gemini Cloud/Code Assist APIs
    "geminicloudassist.googleapis.com",
    "cloudaicompanion.googleapis.com",
    "monitoring.googleapis.com",
    "cloudasset.googleapis.com",
    "recommender.googleapis.com",
    "appoptimize.googleapis.com",

    # Monitoring Type APIs
    "dns.googleapis.com",                        # needed to enable DNS logging
    "firewallinsights.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "securitycenter.googleapis.com",
    "securitycentermanagement.googleapis.com",
    "websecurityscanner.googleapis.com",

    # Standard Type APIs
    "cloudresourcemanager.googleapis.com",
    "storage-api.googleapis.com",
    "storage-component.googleapis.com",
    "storage.googleapis.com",
  ]
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# VertexAI APIs
output "apis_vertexai_freeform_project" {value = var.apis_vertexai_freeform_project}

variable "apis_vertexai_freeform_project" {
  description = "APIs for Vertex AI Freeform project."
  type        = list(string)
  default     = [
    # Project APIs
    "aiplatform.googleapis.com",
    "cloudaicompanion.googleapis.com",
    "visionai.googleapis.com",

    # Monitoring Type APIs
    "dns.googleapis.com",                        # needed to enable DNS logging
    "firewallinsights.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "securitycenter.googleapis.com",
    "securitycentermanagement.googleapis.com",
    "websecurityscanner.googleapis.com",

    # Standard Type APIs
    "cloudresourcemanager.googleapis.com",
    "storage-api.googleapis.com",
    "storage-component.googleapis.com",
    "storage.googleapis.com",
    
  ]
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# VertexAI Workbench APIs
output "apis_vertexai_workbench_project" {value = var.apis_vertexai_workbench_project}

variable "apis_vertexai_workbench_project" {
  description = "APIs for Vertex AI-Workbench project."
  type        = list(string)
  default     = [
    # Project APIs
    # "accesscontextmanager.googleapis.com",     # lack permissions to use
    "aiplatform.googleapis.com",
    "cloudaicompanion.googleapis.com",
    "compute.googleapis.com",
    "dataform.googleapis.com",
    "networkconnectivity.googleapis.com",        # runtime troubleshooting add-on, may not be needed
    "notebooks.googleapis.com",
    "oslogin.googleapis.com",                    # for VM login
    "privilegedaccessmanager.googleapis.com",
    "secretmanager.googleapis.com",
    "servicenetworking.googleapis.com",          # needed for service network
    "visionai.googleapis.com",

    # BigQuery APIs
    "bigquery.googleapis.com",
    "bigquerystorage.googleapis.com",

    # Gemini Cloud/Code Assist APIs
    "geminicloudassist.googleapis.com",
    "cloudaicompanion.googleapis.com",
    "monitoring.googleapis.com",
    "cloudasset.googleapis.com",
    "recommender.googleapis.com",
    "appoptimize.googleapis.com",

    # Monitoring Type APIs
    "dns.googleapis.com",                        # needed to enable DNS logging
    "firewallinsights.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "securitycenter.googleapis.com",
    "securitycentermanagement.googleapis.com",
    "websecurityscanner.googleapis.com",

    # Standard Type APIs
    "cloudresourcemanager.googleapis.com",
    "storage-api.googleapis.com",
    "storage-component.googleapis.com",
    "storage.googleapis.com",
  ]
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
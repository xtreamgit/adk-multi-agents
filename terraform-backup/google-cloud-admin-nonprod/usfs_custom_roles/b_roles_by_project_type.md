# Table of Contents
Admin Architecture Testing
BillingBQ
Create VertexAI Chatbot Project
Earth Engine Project
Earth Engine, BigQuery, Colab Enterprise Project
Gemini
VertexAI Colab Enterprise Project
VertexAI Freeform Project
VertexAI Workbench BigQuery Project

-------------------------------------------------

# Admin Architecture Testing

## User
### Pre-define role list
"roles/aiplatform.admin",
"roles/alloydb.admin",
"roles/apigee.admin",
"roles/bigquery.admin",
"roles/cloudkms.admin",
"roles/cloudsql.admin",
"roles/composer.worker",
"roles/compute.networkAdmin",
"roles/compute.securityAdmin",
"roles/dataflow.admin",
"roles/dlp.admin",
"roles/iam.serviceAccountAdmin",    
"roles/iam.securityAdmin",    
"roles/logging.admin",
"roles/notebooks.legacyAdmin",
"roles/notebooks.runner",
"roles/pubsub.admin",
"roles/resourcemanager.projectIamAdmin",
"roles/run.admin",
"roles/serviceusage.serviceUsageAdmin",   
"roles/storage.admin",

-------------------------------------------------

# BillingBQ Project

## Viewer
### Custom role list
module.usfs_custom_roles.usfs_storage_viewer.out_name,
### Pre-define role list
"roles/bigquery.dataViewer",
"roles/bigquery.jobUser",
"roles/bigquery.readSessionUser", 

## SA-powerbi-bq-access
### Custom role list
### Pre-define role list
"roles/bigquery.dataViewer",
"roles/bigquery.jobUser",
"roles/bigquery.readSessionUser",

-------------------------------------------------

# Create VertexAI Chatbot Project

## Developer
### Custom role list
module.usfs_custom_roles.usfs_compute_instancemanager.out_name,
module.usfs_custom_roles.usfs_notebooks_manager.out_name,
module.usfs_custom_roles.usfs_storage_user.out_name,
module.usfs_custom_roles.usfs_vertexai_user.out_name,
### Pre-define role list
"roles/bigquery.user",
"roles/compute.admin",                        # Compute Admin, needed to configure application access
"roles/compute.osLogin",
"roles/datastore.user",                       # Cloud Datastore User
"roles/dialogflow.consoleAgentEditor",        # Dialog Console Agent Editor
"roles/dialogflow.reader",                    # Dialogflow Reader
"roles/dataform.codeCreator",
"roles/dataform.codeViewer",
"roles/discoveryengine.admin",                # Discovery Engine Admin, needed to create chatbot
"roles/discoveryengine.viewer",
"roles/documentai.viewer",
"roles/iam.securityReviewer",                 # IAM Security Reviewer, needed to configure application access
"roles/iam.serviceAccountUser",
"roles/logging.viewer",
"roles/monitoring.viewer",
"roles/notebooks.runner",                     # Role includes compute.viewer permissions
"roles/run.builder",                          # Cloud Run Builder
"roles/run.developer",                        # Cloud Run Developer
"roles/run.invoker",                          # Cloud Run Invoker"
"roles/run.sourceDeveloper",                  # Cloud Run Source Developer
"roles/run.viewer",                           # Cloud Run Viewer
"roles/serviceusage.serviceUsageConsumer",
"roles/storagetransfer.user",
"roles/visionai.analysisViewer",
"roles/visionai.eventViewer",
"roles/visionai.operatorViewer",

## Viewer (Chatbot User)
### Custom role list
module.usfs_custom_roles.usfs_storage_viewer.out_name,
### Pre-define role list
"roles/aiplatform.viewer",
"roles/bigquery.dataViewer",
"roles/dataform.codeViewer",
"roles/discoveryengine.viewer",
"roles/documentai.viewer",
"roles/visionai.analysisViewer",
"roles/visionai.eventViewer",
"roles/visionai.operatorViewer",

## SA-cloudservices
### Custom role list
### Pre-define role list
"roles/compute.instanceAdmin.v1",
"roles/iam.serviceAccountUser",     # Only needed if SA creates VMs that can run as a service account

## SA-compute-developer
### Custom role list
module.usfs_custom_roles.usfs_storage_viewer.out_name,
### Pre-define role list
"roles/logging.logWriter",        # 
"roles/run.serviceAgent",         # Cloud Run Service Agent

## SA-@serverless-robot
### Pre-define role list
"roles/run.serviceAgent",
"roles/clouddeploymentmanager.serviceAgent",

-------------------------------------------------

# Earth Engine Project

## User
### Custom role list
module.usfs_custom_roles.usfs_storage_user.out_name,
### Pre-defined role list
"roles/earthengine.writer",
"roles/serviceusage.serviceUsageConsumer",

## App Publisher
### Pre-defined role list
"roles/earthengine.appsPublisher"

## Viewer
### Custom role list
module.usfs_custom_roles.usfs_storage_viewer.out_name,
### Pre-defined role list
"roles/earthengine.viewer",

-------------------------------------------------

# Earth Engine, BigQuery, Colab Enterprise Project

## User
### Custom role list
module.usfs_custom_roles.usfs_notebooks_start_stop.out_name,
module.usfs_custom_roles.usfs_storage_user.out_name, 
module.usfs_custom_roles.usfs_vertexai_user.out_name, 
### Pre-defined role list
"roles/earthengine.writer",
"roles/bigquery.user",
"roles/dataform.codeCreator",
"roles/dataform.codeViewer",
"roles/dataplex.catalogViewer",
"roles/serviceusage.serviceUsageConsumer",
"roles/notebooks.runner",  # Role includes compute.viewer permissions
"roles/storagetransfer.user",
"roles/visionai.analysisViewer",
"roles/visionai.eventViewer",
"roles/visionai.operatorViewer",

-------------------------------------------------

# Gemini roles
"roles/cloudasset.viewer",
"roles/geminicloudassist.user",
"roles/cloudaicompanion.user",
"roles/cloudaicompanion.codeToolsUser",
"roles/serviceusage.serviceUsageConsumer",     

-------------------------------------------------

# VertexAI Colab Enterprise Project

## User
### Custom role list
module.usfs_custom_roles.usfs_notebooks_start_stop.out_name,
module.usfs_custom_roles.usfs_storage_user.out_name, 
module.usfs_custom_roles.usfs_vertexai_user.out_name,      
### Pre-defined role list
"roles/dataform.codeCreator",
"roles/dataform.codeViewer",
"roles/serviceusage.serviceUsageConsumer",
"roles/notebooks.runner",  # Role includes compute.viewer permissions
"roles/storagetransfer.user",
"roles/visionai.analysisViewer",
"roles/visionai.eventViewer",
"roles/visionai.operatorViewer",

## Addon...Notebook Manager
### Custom role list
module.usfs_custom_roles.usfs_compute_instancemanager.out_name,
module.usfs_custom_roles.usfs_notebooks_manager.out_name
### Pre-define role list

## Viewer
### Custom role list
### Pre-define role list

-------------------------------------------------

# VertexAI Freeform Project

## User
### Custom role list
module.usfs_custom_roles.usfs_storage_user.out_name, 
module.usfs_custom_roles.usfs_vertexai_user.out_name,      
### Pre-defined role list
"roles/serviceusage.serviceUsageConsumer",
"roles/visionai.analysisViewer",
"roles/visionai.eventViewer",
"roles/visionai.operatorViewer",

-------------------------------------------------

# VertexAI Workbench BigQuery Project

## User
### Custom role list
module.usfs_custom_roles.usfs_notebooks_start_stop.out_name,
module.usfs_custom_roles.usfs_storage_user.out_name, 
module.usfs_custom_roles.usfs_vertexai_user.out_name,      
### Pre-defined role list
"roles/bigquery.user",
"roles/compute.osLogin",
"roles/dataform.codeCreator",
"roles/dataform.codeViewer",
"roles/documentai.viewer",
"roles/serviceusage.serviceUsageConsumer",
"roles/notebooks.runner",  # Role includes compute.viewer permissions
"roles/storagetransfer.user",
"roles/visionai.analysisViewer",
"roles/visionai.eventViewer",
"roles/visionai.operatorViewer",

## Addon...Notebook Manager
### Custom role list
module.usfs_custom_roles.usfs_compute_instancemanager.out_name,
module.usfs_custom_roles.usfs_notebooks_manager.out_name,

## Viewer
### Custom role list
module.usfs_custom_roles.usfs_storage_viewer.out_name,
### Pre-define role list
"roles/aiplatform.viewer",
"roles/bigquery.dataViewer",
"roles/compute.viewer",
"roles/dataform.codeViewer",
"roles/documentai.viewer",
"roles/notebooks.viewer",
"roles/visionai.analysisViewer",
"roles/visionai.eventViewer",
"roles/visionai.operatorViewer",

## Storage Viewer
### Custom role list
module.usfs_custom_roles.usfs_storage_viewer.out_name,

## SA-compute@developer
"serviceAccount:${var.project_number}-compute@developer.gserviceaccount.com"
### Custom role list
module.usfs_custom_roles.usfs_storage_user.out_name,

-------------------------------------------------
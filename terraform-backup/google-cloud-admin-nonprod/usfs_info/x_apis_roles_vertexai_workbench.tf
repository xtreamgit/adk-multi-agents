
# To get list of permissions for an existing role, use:
# gcloud iam roles describe roles/<role.name>
# Note: setup of roles needs to include three roles:
#       1) user role
#       2) additional permissions role (set perms to null if not needed)
#       3) viewer role (set perms to null if not needed)

# # Project apis outputs
# output "apis_vertexai_workbench_project" {value = var.apis_vertexai_workbench_project}

# # Project user role outputs
# output "cust_role_vertexai_workbench_user_name" {value = var.cust_role_vertexai_workbench_user_name}
# output "cust_role_vertexai_workbench_user_disp_name" {value = var.cust_role_vertexai_workbench_user_disp_name}
# output "cust_role_vertexai_workbench_user_desc" {value = var.cust_role_vertexai_workbench_user_desc}
# output "cust_role_vertexai_workbench_user_perms" {value = concat(
#   var.cust_role_vertexai_workbench_user_perms,
#   var.perms_serviceaccountuser,
#   var.perms_serviceusageconsumer,
#   var.perms_storage_user,
#   var.perms_storagetransferuser,
#   )}

# # Project user addon role outputs (if needed)
# output "cust_role_vertexai_workbench_addon_name" {value = var.cust_role_vertexai_workbench_addon_name}
# output "cust_role_vertexai_workbench_addon_disp_name" {value = var.cust_role_vertexai_workbench_addon_disp_name}
# output "cust_role_vertexai_workbench_addon_desc" {value = var.cust_role_vertexai_workbench_addon_desc}
# output "cust_role_vertexai_workbench_addon_perms" {value = concat(
#   var.cust_role_vertexai_workbench_addon_perms,
#   )}

# # Project viewer role outputs (if needed)
# output "cust_role_vertexai_workbench_viewer_name" {value = var.cust_role_vertexai_workbench_viewer_name}
# output "cust_role_vertexai_workbench_viewer_disp_name" {value = var.cust_role_vertexai_workbench_viewer_disp_name}
# output "cust_role_vertexai_workbench_viewer_desc" {value = var.cust_role_vertexai_workbench_viewer_desc}
# output "cust_role_vertexai_workbench_viewer_perms" {value = concat(
#   var.cust_role_vertexai_workbench_viewer_perms,
#   )}

# #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# # api list for project
# variable "apis_vertexai_workbench_project" {
#   description = "APIs for a Vertex AI-Workbench project."
#   type        = list(string)
#   default     = [
#     # Project APIs
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

#     # BigQuery Roles
#     "bigquery.googleapis.com",
#     "bigquerystorage.googleapis.com",

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
# variable "cust_role_vertexai_workbench_user_name" {
#   description = "Name of Vertex AI-Workbench user role."
#   type        = string
#   default     = "USFSVertexAIWorkbenchUser"
# }

# variable "cust_role_vertexai_workbench_user_disp_name" {
#   description = "Display name of Vertex AI-Workbench user role."
#   type        = string
#   default     = "USFS Vertex AI-Workbench User"
# }

# variable "cust_role_vertexai_workbench_user_desc" {
#   description = "Description of Vertex AI-Workbench user role."
#   type        = string
#   default     = "USFS Vertex AI-Workbench user role."
# }

# variable "cust_role_vertexai_workbench_user_perms" {
#   description = "List of Vertex AI-Workbench user role permissions."
#   type        = list(string)
#   default     = [
#     # Vertex AI User 
#     # gcloud iam roles describe roles/aiplatform.user
#     # "aiplatform.agentExamples.create",
#     # "aiplatform.agentExamples.delete",
#     "aiplatform.agentExamples.get",
#     "aiplatform.agentExamples.list",
#     # "aiplatform.agentExamples.update",
#     # "aiplatform.agents.create",
#     # "aiplatform.agents.delete",
#     "aiplatform.agents.get",
#     "aiplatform.agents.list",
#     # "aiplatform.agents.update",
#     # "aiplatform.annotationSpecs.create",
#     # "aiplatform.annotationSpecs.delete",
#     "aiplatform.annotationSpecs.get",
#     "aiplatform.annotationSpecs.list",
#     # "aiplatform.annotationSpecs.update",
#     # "aiplatform.annotations.create",
#     # "aiplatform.annotations.delete",
#     "aiplatform.annotations.get",
#     "aiplatform.annotations.list",
#     # "aiplatform.annotations.update",
#     # "aiplatform.apps.create",
#     # "aiplatform.apps.delete",
#     "aiplatform.apps.get",
#     "aiplatform.apps.list",
#     # "aiplatform.apps.update",
#     # "aiplatform.artifacts.create",
#     # "aiplatform.artifacts.delete",
#     "aiplatform.artifacts.get",
#     "aiplatform.artifacts.list",
#     # "aiplatform.artifacts.update",
#     "aiplatform.batchPredictionJobs.cancel",
#     "aiplatform.batchPredictionJobs.create",
#     "aiplatform.batchPredictionJobs.delete",
#     "aiplatform.batchPredictionJobs.get",
#     "aiplatform.batchPredictionJobs.list",
#     "aiplatform.cacheConfigs.get",
#     "aiplatform.consents.get",
#     # "aiplatform.contexts.addContextArtifactsAndExecutions",
#     # "aiplatform.contexts.addContextChildren",
#     # "aiplatform.contexts.create",
#     # "aiplatform.contexts.delete",
#     "aiplatform.contexts.get",
#     "aiplatform.contexts.list",
#     "aiplatform.contexts.queryContextLineageSubgraph",
#     # "aiplatform.contexts.update",
#     "aiplatform.customJobs.cancel",
#     "aiplatform.customJobs.create",
#     "aiplatform.customJobs.delete",
#     "aiplatform.customJobs.get",
#     "aiplatform.customJobs.list",
#     # "aiplatform.dataItems.create",
#     # "aiplatform.dataItems.delete",
#     "aiplatform.dataItems.get",
#     "aiplatform.dataItems.list",
#     # "aiplatform.dataItems.update",
#     "aiplatform.dataLabelingJobs.cancel",
#     "aiplatform.dataLabelingJobs.create",
#     "aiplatform.dataLabelingJobs.delete",
#     "aiplatform.dataLabelingJobs.get",
#     "aiplatform.dataLabelingJobs.list",
#     # "aiplatform.datasetVersions.create",
#     # "aiplatform.datasetVersions.delete",
#     "aiplatform.datasetVersions.get",
#     "aiplatform.datasetVersions.list",
#     # "aiplatform.datasetVersions.restore",
#     "aiplatform.datasets.create",
#     "aiplatform.datasets.delete",
#     "aiplatform.datasets.export",
#     "aiplatform.datasets.get",
#     "aiplatform.datasets.import",
#     "aiplatform.datasets.list",
#     "aiplatform.datasets.update",
#     # "aiplatform.deploymentResourcePools.create",
#     # "aiplatform.deploymentResourcePools.delete",
#     "aiplatform.deploymentResourcePools.get",
#     "aiplatform.deploymentResourcePools.list",
#     "aiplatform.deploymentResourcePools.queryDeployedModels",
#     # "aiplatform.deploymentResourcePools.update",
#     # "aiplatform.edgeDeploymentJobs.create",
#     # "aiplatform.edgeDeploymentJobs.delete",
#     "aiplatform.edgeDeploymentJobs.get",
#     "aiplatform.edgeDeploymentJobs.list",
#     "aiplatform.edgeDeviceDebugInfo.get",
#     # "aiplatform.edgeDevices.create",
#     # "aiplatform.edgeDevices.delete",
#     "aiplatform.edgeDevices.get",
#     "aiplatform.edgeDevices.list",
#     # "aiplatform.edgeDevices.update",
#     "aiplatform.endpoints.create",
#     "aiplatform.endpoints.delete",
#     "aiplatform.endpoints.deploy",
#     "aiplatform.endpoints.explain",
#     "aiplatform.endpoints.get",
#     "aiplatform.endpoints.list",
#     "aiplatform.endpoints.predict",
#     "aiplatform.endpoints.undeploy",
#     "aiplatform.endpoints.update",
#     # "aiplatform.entityTypes.create",
#     # "aiplatform.entityTypes.delete",
#     # "aiplatform.entityTypes.deleteFeatureValues",
#     # "aiplatform.entityTypes.exportFeatureValues",
#     "aiplatform.entityTypes.get",
#     # "aiplatform.entityTypes.importFeatureValues",
#     "aiplatform.entityTypes.list",
#     # "aiplatform.entityTypes.readFeatureValues",
#     # "aiplatform.entityTypes.streamingReadFeatureValues",
#     # "aiplatform.entityTypes.update",
#     # "aiplatform.entityTypes.writeFeatureValues",
#     # "aiplatform.executions.addExecutionEvents",
#     # "aiplatform.executions.create",
#     # "aiplatform.executions.delete",
#     "aiplatform.executions.get",
#     "aiplatform.executions.list",
#     "aiplatform.executions.queryExecutionInputsAndOutputs",
#     # "aiplatform.executions.update",
#     # "aiplatform.extensions.delete",
#     # "aiplatform.extensions.execute",
#     "aiplatform.extensions.get",
#     # "aiplatform.extensions.import",
#     "aiplatform.extensions.list",
#     # "aiplatform.extensions.update",
#     # "aiplatform.featureGroups.create",
#     # "aiplatform.featureGroups.delete",
#     "aiplatform.featureGroups.get",
#     "aiplatform.featureGroups.list",
#     # "aiplatform.featureGroups.update",
#     # "aiplatform.featureOnlineStores.create",
#     # "aiplatform.featureOnlineStores.delete",
#     "aiplatform.featureOnlineStores.get",
#     "aiplatform.featureOnlineStores.list",
#     # "aiplatform.featureOnlineStores.update",
#     "aiplatform.featureViewSyncs.get",
#     "aiplatform.featureViewSyncs.list",
#     # "aiplatform.featureViews.create",
#     # "aiplatform.featureViews.delete",
#     "aiplatform.featureViews.fetchFeatureValues",
#     "aiplatform.featureViews.get",
#     "aiplatform.featureViews.list",
#     "aiplatform.featureViews.searchNearestEntities",
#     # "aiplatform.featureViews.sync",
#     # "aiplatform.featureViews.update",
#     # "aiplatform.features.create",
#     # "aiplatform.features.delete",
#     "aiplatform.features.get",
#     "aiplatform.features.list",
#     # "aiplatform.features.update",
#     # "aiplatform.featurestores.batchReadFeatureValues",
#     # "aiplatform.featurestores.create",
#     # "aiplatform.featurestores.delete",
#     # "aiplatform.featurestores.exportFeatures",
#     "aiplatform.featurestores.get",
#     # "aiplatform.featurestores.importFeatures",
#     "aiplatform.featurestores.list",
#     # "aiplatform.featurestores.readFeatures",
#     # "aiplatform.featurestores.update",
#     # "aiplatform.featurestores.writeFeatures",
#     # "aiplatform.humanInTheLoops.cancel",
#     # "aiplatform.humanInTheLoops.create",
#     # "aiplatform.humanInTheLoops.delete",
#     "aiplatform.humanInTheLoops.get",
#     "aiplatform.humanInTheLoops.list",
#     # "aiplatform.humanInTheLoops.queryAnnotationStats",
#     # "aiplatform.humanInTheLoops.send",
#     # "aiplatform.humanInTheLoops.update",
#     "aiplatform.hyperparameterTuningJobs.cancel",
#     "aiplatform.hyperparameterTuningJobs.create",
#     "aiplatform.hyperparameterTuningJobs.delete",
#     "aiplatform.hyperparameterTuningJobs.get",
#     "aiplatform.hyperparameterTuningJobs.list",
#     # "aiplatform.indexEndpoints.create",
#     # "aiplatform.indexEndpoints.delete",
#     # "aiplatform.indexEndpoints.deploy",
#     "aiplatform.indexEndpoints.get",
#     "aiplatform.indexEndpoints.list",
#     "aiplatform.indexEndpoints.queryVectors",
#     # "aiplatform.indexEndpoints.undeploy",
#     # "aiplatform.indexEndpoints.update",
#     # "aiplatform.indexes.create",
#     # "aiplatform.indexes.delete",
#     "aiplatform.indexes.get",
#     "aiplatform.indexes.list",
#     # "aiplatform.indexes.update",
#     "aiplatform.locations.get",
#     "aiplatform.locations.list",
#     "aiplatform.metadataSchemas.create",
#     "aiplatform.metadataSchemas.delete",
#     "aiplatform.metadataSchemas.get",
#     "aiplatform.metadataSchemas.list",
#     "aiplatform.metadataStores.create",
#     "aiplatform.metadataStores.delete",
#     "aiplatform.metadataStores.get",
#     "aiplatform.metadataStores.list",
#     "aiplatform.modelDeploymentMonitoringJobs.create",
#     "aiplatform.modelDeploymentMonitoringJobs.delete",
#     "aiplatform.modelDeploymentMonitoringJobs.get",
#     "aiplatform.modelDeploymentMonitoringJobs.list",
#     "aiplatform.modelDeploymentMonitoringJobs.pause",
#     "aiplatform.modelDeploymentMonitoringJobs.resume",
#     "aiplatform.modelDeploymentMonitoringJobs.searchStatsAnomalies",
#     "aiplatform.modelDeploymentMonitoringJobs.update",
#     "aiplatform.modelEvaluationSlices.get",
#     "aiplatform.modelEvaluationSlices.import",
#     "aiplatform.modelEvaluationSlices.list",
#     "aiplatform.modelEvaluations.exportEvaluatedDataItems",
#     "aiplatform.modelEvaluations.get",
#     "aiplatform.modelEvaluations.import",
#     "aiplatform.modelEvaluations.list",
#     "aiplatform.modelMonitoringJobs.create",
#     "aiplatform.modelMonitoringJobs.delete",
#     "aiplatform.modelMonitoringJobs.get",
#     "aiplatform.modelMonitoringJobs.list",
#     "aiplatform.modelMonitors.create",
#     "aiplatform.modelMonitors.delete",
#     "aiplatform.modelMonitors.get",
#     "aiplatform.modelMonitors.list",
#     "aiplatform.modelMonitors.searchModelMonitoringAlerts",
#     "aiplatform.modelMonitors.searchModelMonitoringStats",
#     "aiplatform.modelMonitors.update",
#     "aiplatform.models.delete",
#     "aiplatform.models.export",
#     "aiplatform.models.get",
#     "aiplatform.models.list",
#     "aiplatform.models.update",
#     "aiplatform.models.upload",
#     # "aiplatform.nasJobs.cancel",
#     # "aiplatform.nasJobs.create",
#     # "aiplatform.nasJobs.delete",
#     "aiplatform.nasJobs.get",
#     "aiplatform.nasJobs.list",
#     "aiplatform.nasTrialDetails.get",
#     "aiplatform.nasTrialDetails.list",
#     "aiplatform.notebookExecutionJobs.create",
#     "aiplatform.notebookExecutionJobs.delete",
#     "aiplatform.notebookExecutionJobs.get",
#     "aiplatform.notebookExecutionJobs.list",
#     "aiplatform.notebookRuntimeTemplates.apply",
#     # "aiplatform.notebookRuntimeTemplates.create",
#     # "aiplatform.notebookRuntimeTemplates.delete",
#     "aiplatform.notebookRuntimeTemplates.get",
#     "aiplatform.notebookRuntimeTemplates.list",
#     # "aiplatform.notebookRuntimeTemplates.update",
#     "aiplatform.notebookRuntimes.assign",
#     "aiplatform.notebookRuntimes.delete",
#     "aiplatform.notebookRuntimes.get",
#     "aiplatform.notebookRuntimes.list",
#     "aiplatform.notebookRuntimes.start",
#     # "aiplatform.notebookRuntimes.update",
#     # "aiplatform.notebookRuntimes.upgrade",
#     "aiplatform.operations.list",
#     "aiplatform.persistentResources.get",
#     "aiplatform.persistentResources.list",
#     "aiplatform.pipelineJobs.cancel",
#     "aiplatform.pipelineJobs.create",
#     "aiplatform.pipelineJobs.delete",
#     "aiplatform.pipelineJobs.get",
#     "aiplatform.pipelineJobs.list",
#     # "aiplatform.reasoningEngines.create",
#     # "aiplatform.reasoningEngines.delete",
#     "aiplatform.reasoningEngines.get",
#     "aiplatform.reasoningEngines.list",
#     "aiplatform.reasoningEngines.query",
#     # "aiplatform.reasoningEngines.update",
#     # "aiplatform.schedules.create",
#     # "aiplatform.schedules.delete",
#     "aiplatform.schedules.get",
#     "aiplatform.schedules.list",
#     # "aiplatform.schedules.update",
#     "aiplatform.sessions.get",
#     "aiplatform.sessions.list",
#     "aiplatform.sessions.run",
#     # "aiplatform.specialistPools.create",
#     # "aiplatform.specialistPools.delete",
#     "aiplatform.specialistPools.get",
#     "aiplatform.specialistPools.list",
#     "aiplatform.specialistPools.update",
#     # "aiplatform.studies.create",
#     # "aiplatform.studies.delete",
#     "aiplatform.studies.get",
#     "aiplatform.studies.list",
#     # "aiplatform.studies.update",
#     # "aiplatform.tensorboardExperiments.create",
#     # "aiplatform.tensorboardExperiments.delete",
#     "aiplatform.tensorboardExperiments.get",
#     "aiplatform.tensorboardExperiments.list",
#     # "aiplatform.tensorboardExperiments.update",
#     # "aiplatform.tensorboardExperiments.write",
#     # "aiplatform.tensorboardRuns.batchCreate",
#     # "aiplatform.tensorboardRuns.create",
#     # "aiplatform.tensorboardRuns.delete",
#     "aiplatform.tensorboardRuns.get",
#     "aiplatform.tensorboardRuns.list",
#     # "aiplatform.tensorboardRuns.update",
#     # "aiplatform.tensorboardRuns.write",
#     # "aiplatform.tensorboardTimeSeries.batchCreate",
#     "aiplatform.tensorboardTimeSeries.batchRead",
#     # "aiplatform.tensorboardTimeSeries.create",
#     # "aiplatform.tensorboardTimeSeries.delete",
#     "aiplatform.tensorboardTimeSeries.get",
#     "aiplatform.tensorboardTimeSeries.list",
#     "aiplatform.tensorboardTimeSeries.read",
#     # "aiplatform.tensorboardTimeSeries.update",
#     # "aiplatform.tensorboards.create",
#     # "aiplatform.tensorboards.delete",
#     "aiplatform.tensorboards.get",
#     "aiplatform.tensorboards.list",
#     # "aiplatform.tensorboards.update",
#     "aiplatform.trainingPipelines.cancel",
#     "aiplatform.trainingPipelines.create",
#     "aiplatform.trainingPipelines.delete",
#     "aiplatform.trainingPipelines.get",
#     "aiplatform.trainingPipelines.list",
#     "aiplatform.trials.create",
#     "aiplatform.trials.delete",
#     "aiplatform.trials.get",
#     "aiplatform.trials.list",
#     "aiplatform.trials.update",
#     "aiplatform.tuningJobs.cancel",
#     "aiplatform.tuningJobs.create",
#     "aiplatform.tuningJobs.delete",
#     "aiplatform.tuningJobs.get",
#     "aiplatform.tuningJobs.list",
#     "aiplatform.tuningJobs.vertexTune",
#     "resourcemanager.projects.get",
#     # "resourcemanager.projects.list",          # n/a at project level

#     # Custom additional Vertex AI permissions
#     "aiplatform.migratableResources.search",

#     # Big Query - replaced with bigquery.user role
#     # "bigquery.datasets.create", 
#     # "bigquery.datasets.get", 
#     # "bigquery.datasets.getIamPolicy", 
#     # "bigquery.jobs.create",
#     # "bigquery.jobs.list", 
#     # "bigquery.models.list", 
#     # "bigquery.reservationAssignments.list", 
#     # "bigquery.reservations.list", 
#     # "bigquery.routines.list", 
#     # "bigquery.savedqueries.list", 
#     # "bigquery.tables.list", 
#     # "bigquery.transfers.get", 

#     # BigQuery permissions
#     # gcloud iam roles describe roles/bigquery.user
#     "bigquery.bireservations.get",
#     "bigquery.capacityCommitments.get",
#     "bigquery.capacityCommitments.list",
#     "bigquery.config.get",
#     "bigquery.datasets.create",
#     "bigquery.datasets.get",
#     "bigquery.datasets.getIamPolicy",
#     "bigquery.jobs.create",
#     "bigquery.jobs.list",
#     "bigquery.models.list",
#     "bigquery.readsessions.create",
#     "bigquery.readsessions.getData",
#     "bigquery.readsessions.update",
#     "bigquery.reservationAssignments.list",
#     "bigquery.reservationAssignments.search",
#     "bigquery.reservations.get",
#     "bigquery.reservations.list",
#     "bigquery.routines.list",
#     "bigquery.savedqueries.get",
#     "bigquery.savedqueries.list",
#     "bigquery.tables.list",
#     "bigquery.transfers.get",
#     "bigquerymigration.translation.translate",
#     # "dataform.locations.get",         # dataform already included
#     # "dataform.locations.list",
#     # "dataform.repositories.create",
#     # "dataform.repositories.list",
#     "dataplex.projects.search",
#     # "resourcemanager.projects.get",   # resourcemanager already included
#     # "resourcemanager.projects.list",

#     # Compute permissions
#     "compute.acceleratorTypes.list",
#     "compute.addresses.list",
#     "compute.disks.get",
#     "compute.disks.list", 
#     "compute.diskTypes.list",
#     "compute.firewalls.get",
#     "compute.firewalls.list",
#     "compute.instances.get",
#     "compute.instances.getGuestAttributes",
#     "compute.instances.getScreenshot",
#     "compute.instances.getSerialPortOutput",
#     "compute.instances.list", 
#     "compute.instances.listEffectiveTags", 
#     "compute.instances.listReferrers",
#     "compute.instances.osLogin", 
#     "compute.instances.reset",
#     "compute.instances.resume",
#     "compute.instances.start",
#     "compute.instances.stop",
#     "compute.instances.suspend",
#     "compute.projects.get", 
#     "compute.machineTypes.list",
#     "compute.networks.get",
#     "compute.networks.list",
#     "compute.regions.list",
#     "compute.resourcePolicies.list",
#     "compute.subnetworks.get",
#     "compute.subnetworks.list",
#     "compute.targetPools.list",
#     "compute.zones.list",

#     # Dataform permissions
#     "dataform.locations.get",
#     "dataform.locations.list",
#     "dataform.repositories.create",
#     "dataform.repositories.get",
#     "dataform.repositories.list",  

#     # Discovery Engine Viewer (Vertex AI Agent Builder)
#     # gcloud iam roles describe roles/discoveryengine.viewer
#     "discoveryengine.aclConfigs.get",
#     "discoveryengine.analytics.acquireDashboardSession",
#     "discoveryengine.analytics.refreshDashboardSessionTokens",
#     "discoveryengine.answers.get",
#     "discoveryengine.branches.get",
#     "discoveryengine.branches.list",
#     "discoveryengine.cmekConfigs.get",
#     "discoveryengine.cmekConfigs.list",
#     "discoveryengine.collections.get",
#     "discoveryengine.collections.list",
#     "discoveryengine.completionConfigs.completeQuery",
#     "discoveryengine.completionConfigs.get",
#     "discoveryengine.controls.get",
#     "discoveryengine.controls.list",
#     "discoveryengine.conversations.converse",
#     "discoveryengine.conversations.get",
#     "discoveryengine.conversations.list",
#     "discoveryengine.dataStores.completeQuery",
#     "discoveryengine.dataStores.get",
#     "discoveryengine.dataStores.list",
#     "discoveryengine.documentProcessingConfigs.get",
#     "discoveryengine.documents.batchGetDocumentsMetadata",
#     "discoveryengine.documents.get",
#     "discoveryengine.documents.list",
#     "discoveryengine.engines.get",
#     "discoveryengine.engines.list",
#     "discoveryengine.evaluations.get",
#     "discoveryengine.evaluations.list",
#     "discoveryengine.groundingConfigs.check",
#     "discoveryengine.models.get",
#     "discoveryengine.models.list",
#     "discoveryengine.operations.get",
#     "discoveryengine.operations.list",
#     "discoveryengine.projects.get",
#     "discoveryengine.rankingConfigs.rank",
#     "discoveryengine.sampleQueries.get",
#     "discoveryengine.sampleQueries.list",
#     "discoveryengine.sampleQuerySets.get",
#     "discoveryengine.sampleQuerySets.list",
#     "discoveryengine.schemas.get",
#     "discoveryengine.schemas.list",
#     "discoveryengine.schemas.preview",
#     "discoveryengine.schemas.validate",
#     "discoveryengine.servingConfigs.answer",
#     "discoveryengine.servingConfigs.get",
#     "discoveryengine.servingConfigs.list",
#     "discoveryengine.servingConfigs.recommend",
#     "discoveryengine.servingConfigs.search",
#     "discoveryengine.sessions.get",
#     "discoveryengine.sessions.list",
#     "discoveryengine.siteSearchEngines.get",
#     "discoveryengine.targetSites.get",
#     "discoveryengine.targetSites.list",
#     "discoveryengine.userEvents.fetchStats",
#     "discoveryengine.widgetConfigs.get",
#     # "resourcemanager.projects.get",           # already included
#     # "resourcemanager.projects.list",          # n/a at project level

#     # Documentai Permissions
#     "documentai.locations.get", 
#     "documentai.locations.list", 
#     "documentai.operations.getLegacy", 
#     "documentai.processorTypes.list", 
#     "documentai.processors.get", 
#     "documentai.processors.list", 
#     "documentai.processors.processBatch", 
#     "documentai.processors.processOnline",

#     # Notebook Permissions
#     "notebooks.environments.get", 
#     "notebooks.environments.list",
#     "notebooks.executions.list",
#     "notebooks.instances.get", 
#     "notebooks.instances.list", 
#     "notebooks.instances.reset",
#     "notebooks.instances.start",
#     "notebooks.instances.stop",
#     "notebooks.operations.get",
#     "notebooks.operations.list",
#     "notebooks.runtimes.list",
#     "notebooks.schedules.list",

#     # gcloud iam roles describe roles/visionai.analysisViewer
#     "visionai.analyses.get",
#     "visionai.analyses.list",

#     # gcloud iam roles describe roles/visionai.eventViewer
#     "visionai.events.get",
#     "visionai.events.list",

#     # gcloud iam roles describe roles/visionai.operatorViewer
#     "visionai.operators.get",
#     "visionai.operators.list",
#   ]
# }

# #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# # Custom role: user add-on role
# variable "cust_role_vertexai_workbench_addon_name" {
#   description = "Name of Vertex AI-Workbench Add-on role."
#   type        = string
#   default     = "USFSVertexAIWorkbenchAddOn"
# }

# variable "cust_role_vertexai_workbench_addon_disp_name" {
#   description = "Display name of Vertex AI-Workbench Add-on role."
#   type        = string
#   default     = "USFS Vertex AI-Workbench Add-on"
# }

# variable "cust_role_vertexai_workbench_addon_desc" {
#   description = "Description of Vertex AI-Workbench Add-on role."
#   type        = string
#   default     = "USFS Vertex AI-Workbench Add-on role. Role assumes user is already a user role member."
# }

# variable "cust_role_vertexai_workbench_addon_perms" {
#   description = "List of Vertex AI-Workbench Add-on role permissions."
#   type        = list(string)
#   default     = []
#   # default     = [
#   #   # Note: role adds functionality to user role. User must also be member of user role.
#   #   # User add-on permissions
#   # ]
# }

# #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# # Custom role: viewer
# variable "cust_role_vertexai_workbench_viewer_name" {
#   description = "Name of Vertex AI-Workbench viewer role."
#   type        = string
#   default     = "USFSVertexAIWorkbenchViewer"
# }

# variable "cust_role_vertexai_workbench_viewer_disp_name" {
#   description = "Display name of Vertex AI-Workbench viewer role."
#   type        = string
#   default     = "USFS Vertex AI-Workbench Viewer"
# }

# variable "cust_role_vertexai_workbench_viewer_desc" {
#   description = "Description of Vertex AI-Workbench viewer role."
#   type        = string
#   default     = "USFS Vertex AI-Workbench viewer role."
# }

# variable "cust_role_vertexai_workbench_viewer_perms" {
#   description = "List of Vertex AI-Workbench viewer role permissions."
#   type        = list(string)
#   default     = []
#   # default     = [
#   #   # Viewer permissions
#   # ]
# }
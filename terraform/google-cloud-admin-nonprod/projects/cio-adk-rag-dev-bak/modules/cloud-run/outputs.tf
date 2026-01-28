output "backend_service_name" {
  description = "Name of the backend Cloud Run service"
  value       = google_cloud_run_v2_service.backend.name
}

output "backend_url" {
  description = "URL of the backend Cloud Run service"
  value       = google_cloud_run_v2_service.backend.uri
}

output "frontend_service_name" {
  description = "Name of the frontend Cloud Run service"
  value       = google_cloud_run_v2_service.frontend.name
}

output "frontend_url" {
  description = "URL of the frontend Cloud Run service"
  value       = google_cloud_run_v2_service.frontend.uri
}

output "agent1_service_name" {
  description = "Name of the agent1 Cloud Run service (if enabled)"
  value       = var.enable_multi_agent ? google_cloud_run_v2_service.backend_agent1[0].name : ""
}

output "agent1_url" {
  description = "URL of the agent1 Cloud Run service (if enabled)"
  value       = var.enable_multi_agent ? google_cloud_run_v2_service.backend_agent1[0].uri : ""
}

output "agent2_service_name" {
  description = "Name of the agent2 Cloud Run service (if enabled)"
  value       = var.enable_multi_agent ? google_cloud_run_v2_service.backend_agent2[0].name : ""
}

output "agent2_url" {
  description = "URL of the agent2 Cloud Run service (if enabled)"
  value       = var.enable_multi_agent ? google_cloud_run_v2_service.backend_agent2[0].uri : ""
}

output "agent3_service_name" {
  description = "Name of the agent3 Cloud Run service (if enabled)"
  value       = var.enable_multi_agent ? google_cloud_run_v2_service.backend_agent3[0].name : ""
}

output "agent3_url" {
  description = "URL of the agent3 Cloud Run service (if enabled)"
  value       = var.enable_multi_agent ? google_cloud_run_v2_service.backend_agent3[0].uri : ""
}

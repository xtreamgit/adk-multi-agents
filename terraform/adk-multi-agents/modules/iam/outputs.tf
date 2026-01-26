output "backend_service_account_email" {
  description = "Email of the backend service account"
  value       = google_service_account.backend.email
}

output "backend_service_account_name" {
  description = "Name of the backend service account"
  value       = google_service_account.backend.name
}

output "frontend_service_account_email" {
  description = "Email of the frontend service account"
  value       = google_service_account.frontend.email
}

output "frontend_service_account_name" {
  description = "Name of the frontend service account"
  value       = google_service_account.frontend.name
}

output "agent1_service_account_email" {
  description = "Email of the agent1 service account"
  value       = google_service_account.agent1.email
}

output "agent2_service_account_email" {
  description = "Email of the agent2 service account"
  value       = google_service_account.agent2.email
}

output "agent3_service_account_email" {
  description = "Email of the agent3 service account"
  value       = google_service_account.agent3.email
}

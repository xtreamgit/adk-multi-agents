# Terraform Outputs

output "project_id" {
  description = "The GCP project ID"
  value       = var.project_id
}

output "region" {
  description = "The GCP region"
  value       = var.region
}

output "artifact_registry_repository" {
  description = "Artifact Registry repository URL"
  value       = module.artifact_registry.repository_url
}

output "backend_service_url" {
  description = "Backend Cloud Run service URL (direct)"
  value       = module.cloud_run.backend_url
}

output "frontend_service_url" {
  description = "Frontend Cloud Run service URL (direct)"
  value       = module.cloud_run.frontend_url
}

output "load_balancer_ip" {
  description = "Load balancer static IP address"
  value       = module.load_balancer.static_ip
}

output "load_balancer_url" {
  description = "Load balancer HTTPS URL (nip.io)"
  value       = "https://${module.load_balancer.static_ip}.nip.io"
}

output "ssl_certificate_status" {
  description = "SSL certificate provisioning status"
  value       = module.load_balancer.ssl_certificate_status
}

output "backend_service_account" {
  description = "Backend service account email"
  value       = module.iam.backend_service_account_email
}

output "frontend_service_account" {
  description = "Frontend service account email"
  value       = module.iam.frontend_service_account_email
}

output "agent_service_accounts" {
  description = "Agent service account emails (if multi-agent enabled)"
  value = var.enable_multi_agent ? {
    agent1 = module.iam.agent1_service_account_email
    agent2 = module.iam.agent2_service_account_email
    agent3 = module.iam.agent3_service_account_email
  } : {}
}

output "deployment_instructions" {
  description = "Next steps after Terraform apply"
  value = <<-EOT
  
  ✅ Infrastructure deployed successfully!
  
  🌐 Access your application:
     ${module.load_balancer.static_ip}.nip.io
  
  📝 Next steps:
  
  1. Build and push container images:
     
     # Backend
     gcloud builds submit ./backend \
       --config=backend/cloudbuild.yaml \
       --substitutions=_BACKEND_IMAGE="${var.backend_image}"
     
     # Frontend
     gcloud builds submit ./frontend \
       --config=frontend/cloudbuild.yaml \
       --substitutions=_IMAGE_NAME="${var.frontend_image}",_BACKEND_URL="https://${module.load_balancer.static_ip}.nip.io"
  
  2. Wait for SSL certificate to provision (10-15 minutes):
     
     gcloud compute ssl-certificates describe ${var.ssl_certificate_name} --global
  
  3. Test your deployment:
     
     curl https://${module.load_balancer.static_ip}.nip.io/api/health
  
  📊 Resource URLs:
     - Backend (direct):  ${module.cloud_run.backend_url}
     - Frontend (direct): ${module.cloud_run.frontend_url}
     - Load Balancer:     https://${module.load_balancer.static_ip}.nip.io
  
  EOT
}

# IAM Service Accounts Module
# Creates service accounts for Cloud Run services

# Backend Service Account
resource "google_service_account" "backend" {
  account_id   = "backend-cloud-run-sa"
  display_name = "Backend Cloud Run Service Account"
  description  = "Service account for backend Cloud Run services"
  project      = var.project_id
}

# Grant Backend SA permissions
resource "google_project_iam_member" "backend_permissions" {
  for_each = toset([
    "roles/aiplatform.user",           # Vertex AI access
    "roles/cloudsql.client",           # Cloud SQL access
    "roles/secretmanager.secretAccessor", # Secret Manager access
    "roles/logging.logWriter",         # Cloud Logging
    "roles/cloudtrace.agent",          # Cloud Trace
  ])
  
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.backend.email}"
}

# Frontend Service Account
resource "google_service_account" "frontend" {
  account_id   = "frontend-cloud-run-sa"
  display_name = "Frontend Cloud Run Service Account"
  description  = "Service account for frontend Cloud Run service"
  project      = var.project_id
}

# Grant Frontend SA permissions (minimal)
resource "google_project_iam_member" "frontend_permissions" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/cloudtrace.agent",
  ])
  
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.frontend.email}"
}

# Agent 1 Service Account
resource "google_service_account" "agent1" {
  account_id   = "backend-agent1-sa"
  display_name = "Backend Agent 1 Service Account"
  description  = "Service account for backend-agent1 Cloud Run service"
  project      = var.project_id
}

resource "google_project_iam_member" "agent1_permissions" {
  for_each = toset([
    "roles/aiplatform.user",
    "roles/cloudsql.client",
    "roles/secretmanager.secretAccessor",
    "roles/logging.logWriter",
    "roles/cloudtrace.agent",
  ])
  
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.agent1.email}"
}

# Agent 2 Service Account
resource "google_service_account" "agent2" {
  account_id   = "backend-agent2-sa"
  display_name = "Backend Agent 2 Service Account"
  description  = "Service account for backend-agent2 Cloud Run service"
  project      = var.project_id
}

resource "google_project_iam_member" "agent2_permissions" {
  for_each = toset([
    "roles/aiplatform.user",
    "roles/cloudsql.client",
    "roles/secretmanager.secretAccessor",
    "roles/logging.logWriter",
    "roles/cloudtrace.agent",
  ])
  
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.agent2.email}"
}

# Agent 3 Service Account
resource "google_service_account" "agent3" {
  account_id   = "backend-agent3-sa"
  display_name = "Backend Agent 3 Service Account"
  description  = "Service account for backend-agent3 Cloud Run service"
  project      = var.project_id
}

resource "google_project_iam_member" "agent3_permissions" {
  for_each = toset([
    "roles/aiplatform.user",
    "roles/cloudsql.client",
    "roles/secretmanager.secretAccessor",
    "roles/logging.logWriter",
    "roles/cloudtrace.agent",
  ])
  
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.agent3.email}"
}

# Grant Cloud Build service account permissions
resource "google_project_iam_member" "cloudbuild_permissions" {
  for_each = toset([
    "roles/run.admin",
    "roles/iam.serviceAccountUser",
  ])
  
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${var.project_number}@cloudbuild.gserviceaccount.com"
}

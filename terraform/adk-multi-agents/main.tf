# Main Terraform Configuration
# Deploys complete infrastructure for Cloud Run + Load Balancer architecture
# Based on INFRASTRUCTURE_DEPLOYMENT_GUIDE.md

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
  
  # Uncomment to use remote backend (recommended for team collaboration)
  # backend "gcs" {
  #   bucket = "your-terraform-state-bucket"
  #   prefix = "terraform/state"
  # }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Enable required APIs
resource "google_project_service" "required_apis" {
  for_each = toset([
    "run.googleapis.com",
    "cloudbuild.googleapis.com",
    "artifactregistry.googleapis.com",
    "compute.googleapis.com",
    "secretmanager.googleapis.com",
    "sqladmin.googleapis.com",
    "aiplatform.googleapis.com",
  ])

  service            = each.value
  disable_on_destroy = false
}

# Data source for project information
data "google_project" "project" {
  project_id = var.project_id
}

# Artifact Registry for container images
module "artifact_registry" {
  source = "./modules/artifact-registry"
  
  project_id  = var.project_id
  region      = var.region
  repository_id = var.artifact_registry_name
  
  depends_on = [google_project_service.required_apis]
}

# IAM Service Accounts
module "iam" {
  source = "./modules/iam"
  
  project_id     = var.project_id
  project_number = data.google_project.project.number
  
  depends_on = [google_project_service.required_apis]
}

# Cloud Run Services (Frontend + Backend)
module "cloud_run" {
  source = "./modules/cloud-run"
  
  project_id     = var.project_id
  region         = var.region
  
  # Image configuration
  backend_image  = var.backend_image
  frontend_image = var.frontend_image
  
  # Service accounts
  backend_service_account  = module.iam.backend_service_account_email
  frontend_service_account = module.iam.frontend_service_account_email
  
  # Multi-agent configuration
  enable_multi_agent     = var.enable_multi_agent
  agent_service_accounts = var.enable_multi_agent ? {
    agent1 = module.iam.agent1_service_account_email
    agent2 = module.iam.agent2_service_account_email
    agent3 = module.iam.agent3_service_account_email
  } : {}
  
  # Environment variables
  backend_env_vars = {
    PROJECT_ID            = var.project_id
    GOOGLE_CLOUD_LOCATION = var.region
    VERTEXAI_PROJECT      = var.project_id
    VERTEXAI_LOCATION     = var.region
    LOG_LEVEL             = var.log_level
    ENVIRONMENT           = var.environment
  }
  
  depends_on = [
    google_project_service.required_apis,
    module.iam
  ]
}

# Load Balancer Infrastructure
module "load_balancer" {
  source = "./modules/load-balancer"
  
  project_id = var.project_id
  region     = var.region
  
  # Cloud Run service URLs for NEG creation
  backend_service_name  = module.cloud_run.backend_service_name
  frontend_service_name = module.cloud_run.frontend_service_name
  
  # Multi-agent backend services
  enable_multi_agent        = var.enable_multi_agent
  agent_backend_services = var.enable_multi_agent ? {
    agent1 = module.cloud_run.agent1_service_name
    agent2 = module.cloud_run.agent2_service_name
    agent3 = module.cloud_run.agent3_service_name
  } : {}
  
  # Load balancer configuration
  static_ip_name     = var.static_ip_name
  ssl_certificate_name = var.ssl_certificate_name
  
  depends_on = [
    google_project_service.required_apis,
    module.cloud_run
  ]
}

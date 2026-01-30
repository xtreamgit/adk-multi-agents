# Project description
# Contact: hector@develom.com
# Description: Multi-agent RAG (Retrieval-Augmented Generation) system deployed on Google Cloud Run with Vertex AI integration. Provides intelligent document retrieval and question-answering capabilities across multiple specialized agent backends. Includes frontend UI, load balancer with SSL, and Cloud SQL PostgreSQL database for persistent storage.

# Project information
project_apis = []                           # Add additional project apis if needed.
project_folder                = "folders/132735246914"      # NRE\USFS\CIO\POC
project_id                    = "usfs-cio-adkrag-dev"
project_name                  = "usfs-cio-adkrag-dev"
project_number                = ""                      # Populate after project has been created
project_backup_region         = null                   # To use usfs_info default, set to null
project_region                = null                  # To use usfs_info default, set to null
project_dashboard_label       = "adk-rag-testing"

# Bucket information
bucket_apply_life_cycle_rules       = true          # true; set to false when deleting bucket
bucket_create_backup                = false         # false: set to true to create dual-region bucket for backup
bucket_force_destroy                = false         # false; set to true when deleting bucket
bucket_name_list                    = []            # If none, set to []
bucket_public_access_prevention     = "enforced"    # enforced or inherited; Note: inherited makes bucket public
bucket_soft_delete_seconds          = 604800        # 604800 (7 days); set to 0 when deleting bucket
bucket_versioning                   = true          # true; set to false when deleting bucket

# Group information
group_user_id_list                  = ["group:usfs-gcp-admin@usda.gov"] # Required, format group:<group-email>
group_user_addon_id_list            = []        # If none, set to []
group_viewer_id_list                = []        # If none, set to []

# Project IAM binding expiration map
project_iam_binding_expiration = null
# project_iam_binding_expiration = {
#     title =       "expires_on_YYYY_MM_DD"
#     description = "Expiring at midnight of YYYY-MM-DD"
#     timestamp   = "YYYY-MM-DDT00:00:00Z"
# }

# VM information
vm_create_list            = []   # Leave blank until project image has been created. Populate with vm suffixes, i.e. ["01", "02", "03"]
vm_source_image           = null # Create image from initial vm
vm_initial_boot_disk_size = null
vm_initial_type           = null

# VPC information
vpc_private_access = true # Sets VPC private_ip_google_access

# REQUIRED: GCP Project Configuration
region     = "us-west1"

# REQUIRED: Container Images
# These should be built and pushed to Artifact Registry first
backend_image  = "us-west1-docker.pkg.dev/usfs-cio-adkrag-dev/cloud-run-repo1/backend:latest"
frontend_image = "us-west1-docker.pkg.dev/usfs-cio-adkrag-dev/cloud-run-repo1/frontend:latest"

# Environment
environment = "dev"
log_level   = "INFO"

# Artifact Registry
artifact_registry_name = "cloud-run-repo1"

# Load Balancer Configuration
static_ip_name       = "app-static-ip"
ssl_certificate_name = "app-ssl-cert"

# Multi-Agent Configuration
# Set to true to deploy multiple backend agents
enable_multi_agent = false

# Cloud Run Resource Configuration
# Backend services
backend_cpu           = "1"
backend_memory        = "1Gi"
backend_min_instances = 0
backend_max_instances = 10

# Frontend service
frontend_cpu           = "1"
frontend_memory        = "512Mi"
frontend_min_instances = 0
frontend_max_instances = 5

# Resource Labels
labels = {
  managed-by  = "terraform"
  app         = "cio-adk-rag-dev"
  environment = "dev"
}

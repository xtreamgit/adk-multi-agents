
# usfs info module
module "usfs_info" {
  source = "../../usfs_info"
}

# usfs custom roles
module "usfs_custom_roles" {
  source = "../../usfs_custom_roles"
}

# Bucket information
variable "bucket_apply_life_cycle_rules" {
  description = "Apply storage bucket life cycle rules (true or false)."
  type        = bool
  default     = null
}

variable "bucket_create_backup" {
  description = "Create backup storage bucket (true or false)."
  type        = bool
  default     = null
}

variable "bucket_force_destroy" {
  description = "Enable force destroy of storage bucket (true or false)."
  type        = bool
  default     = null
}

variable "bucket_name_list" {
  description = "Storage bucket name list."
  type        = list(string)
  default     = []
}

variable "bucket_public_access_prevention" {
  description = "Storage bucket public access prevention (enforced or disabled)."
  type        = string
  default     = null
}

variable "bucket_soft_delete_seconds" {
  description = "Storage bucket soft delete time in seconds."
  type        = number
  default     = null
}

variable "bucket_versioning" {
  description = "Set versioning for storage bucket (true or false)."
  type        = bool
  default     = null
}

# Group information
variable "group_user_id_list" {
  description = "User group ID list."
  type        = list(string)
  default     = []
}

variable "group_user_addon_id_list" {
  description = "User addon group ID list."
  type        = list(string)
  default     = []
}

variable "group_viewer_id_list" {
  description = "Viewer group ID list."
  type        = list(string)
  default     = []
}

# Project IAM binding expiration map
variable "project_iam_binding_expiration" {
  description = "Map of project IAM binding expiration parameters."
  type = object({
    title       = string,
    description = string,
    timestamp   = string,
  })
  default = null
  # default = {
  #   title       = "expires_on_2024_12_23"
  #   description = "Expiring at midnight of 2024-12-23"
  #   timestamp   = "2024-12-23T00:00:00Z"
  # }
}

# Project information
variable "project_apis" {
  description = "List of additional project level APIs that should be enabled on the project."
  type        = list(string)
  default     = []
}

variable "project_dashboard_label" {
  description = "Project dashboard label."
  type        = string
  default     = ""
}

variable "project_folder" {
  description = "Folder ID for the project.  Has to be formatted as 'folders/12345678'"
  type        = string
  validation {
    condition     = var.project_folder == null || can(regex("^folders/[0-9]+", var.project_folder))
    error_message = "Projects exist within a parent folder, not directly underneath the organization node.  The format also has to be 'folders/FOLDER_ID'."
  }
}

variable "project_id" {
  description = "The project ID"
  type        = string
  default     = ""
}

variable "project_name" {
  description = "The project name"
  type        = string
  default     = ""
}

variable "project_number" {
  description = "The project number"
  type        = string
  default     = ""
}

variable "project_backup_region" {
  description = "The project backup region"
  type        = string
  default     = ""
}

variable "project_region" {
  description = "The project region"
  type        = string
  default     = ""
}

# VM information
variable "vm_create_list" {
  description = "VM number suffix list"
  type        = list(string)
  default     = []
}

variable "vm_source_image" {
  description = "VM source image"
  type        = string
  default     = null
}

variable "vm_initial_boot_disk_size" {
  description = "Initial VM boot disk size"
  type        = number
  default     = null
}

variable "vm_initial_type" {
  description = "Initial VM type"
  type        = string
  default     = ""
}

# VM map
variable "vm_map" {
  description = "Map of VM parameters for VMs."
  type = map(object({               # vm name
    vm_machine_type = string,       # machine type
    vm_bd_image     = string,       # boot disk image
    vm_bd_size      = number,       # boot disk size
  }))
  default = {}
  # default     = {
  #   "vm-01-apptainer"   = {
  #     vm_machine_type = "e2-standard-8",
  #     vm_bd_image     = "ubuntu-os-cloud/ubuntu-2004-lts",
  #     vm_bd_size      = 150},
  # }
}

# VPC information
variable "vpc_private_access" {
  description = "Set private_ip_google_access for project VPC."
  type        = bool
  default     = null
}

# Variables for Terraform Infrastructure

variable "region" {
  description = "Default region for resources"
  type        = string
  default     = "us-west1"
}

variable "environment" {
  description = "Environment name (production, staging, development)"
  type        = string
  default     = "production"
}

variable "log_level" {
  description = "Application log level"
  type        = string
  default     = "INFO"
}

# Artifact Registry
variable "artifact_registry_name" {
  description = "Name of the Artifact Registry repository"
  type        = string
  default     = "cloud-run-repo1"
}

# Container Images
variable "backend_image" {
  description = "Backend container image URL"
  type        = string
}

variable "frontend_image" {
  description = "Frontend container image URL"
  type        = string
}

# Load Balancer
variable "static_ip_name" {
  description = "Name for the static IP address"
  type        = string
  default     = "app-static-ip"
}

variable "ssl_certificate_name" {
  description = "Name for the SSL certificate"
  type        = string
  default     = "app-ssl-cert"
}

# Multi-Agent Configuration
variable "enable_multi_agent" {
  description = "Enable multi-agent backend services"
  type        = bool
  default     = false
}

# Cloud Run Configuration
variable "backend_cpu" {
  description = "CPU allocation for backend services"
  type        = string
  default     = "1"
}

variable "backend_memory" {
  description = "Memory allocation for backend services"
  type        = string
  default     = "1Gi"
}

variable "backend_min_instances" {
  description = "Minimum number of backend instances"
  type        = number
  default     = 0
}

variable "backend_max_instances" {
  description = "Maximum number of backend instances"
  type        = number
  default     = 10
}

variable "frontend_cpu" {
  description = "CPU allocation for frontend service"
  type        = string
  default     = "1"
}

variable "frontend_memory" {
  description = "Memory allocation for frontend service"
  type        = string
  default     = "512Mi"
}

variable "frontend_min_instances" {
  description = "Minimum number of frontend instances"
  type        = number
  default     = 0
}

variable "frontend_max_instances" {
  description = "Maximum number of frontend instances"
  type        = number
  default     = 5
}

# Labels
variable "labels" {
  description = "Common labels to apply to all resources"
  type        = map(string)
  default = {
    managed-by = "terraform"
    app        = "adk-rag-agent"
  }
}

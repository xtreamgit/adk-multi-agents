# Variables for Terraform Infrastructure

variable "project_id" {
  description = "Google Cloud Project ID"
  type        = string
}

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

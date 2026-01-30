variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP region for Cloud Run services"
  type        = string
}

variable "backend_image" {
  description = "Backend container image URL"
  type        = string
}

variable "frontend_image" {
  description = "Frontend container image URL"
  type        = string
}

variable "backend_service_account" {
  description = "Email of the backend service account"
  type        = string
}

variable "frontend_service_account" {
  description = "Email of the frontend service account"
  type        = string
}

variable "enable_multi_agent" {
  description = "Enable multi-agent backend services"
  type        = bool
  default     = false
}

variable "agent_service_accounts" {
  description = "Map of agent service account emails"
  type        = map(string)
  default     = {}
}

variable "backend_env_vars" {
  description = "Environment variables for backend services"
  type        = map(string)
  default     = {}
}

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

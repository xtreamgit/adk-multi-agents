variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP region for regional resources"
  type        = string
}

variable "static_ip_name" {
  description = "Name for the static IP address"
  type        = string
}

variable "ssl_certificate_name" {
  description = "Name for the SSL certificate"
  type        = string
}

variable "backend_service_name" {
  description = "Name of the backend Cloud Run service"
  type        = string
}

variable "frontend_service_name" {
  description = "Name of the frontend Cloud Run service"
  type        = string
}

variable "enable_multi_agent" {
  description = "Enable multi-agent backend routing"
  type        = bool
  default     = false
}

variable "agent_backend_services" {
  description = "Map of agent backend service names"
  type        = map(string)
  default     = {}
}

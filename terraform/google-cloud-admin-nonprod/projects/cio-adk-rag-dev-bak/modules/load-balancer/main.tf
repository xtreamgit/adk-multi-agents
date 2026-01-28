# Load Balancer Module
# Creates External HTTPS Load Balancer with SSL and path-based routing
# Based on infrastructure/lib/loadbalancer.sh

# Static IP Address
resource "google_compute_global_address" "default" {
  name    = var.static_ip_name
  project = var.project_id
}

# Managed SSL Certificate (using nip.io)
resource "google_compute_managed_ssl_certificate" "default" {
  name    = var.ssl_certificate_name
  project = var.project_id

  managed {
    domains = ["${google_compute_global_address.default.address}.nip.io"]
  }
}

# Network Endpoint Group (NEG) for Frontend
resource "google_compute_region_network_endpoint_group" "frontend" {
  name                  = "frontend-neg"
  project               = var.project_id
  region                = var.region
  network_endpoint_type = "SERVERLESS"

  cloud_run {
    service = var.frontend_service_name
  }
}

# Network Endpoint Group (NEG) for Backend
resource "google_compute_region_network_endpoint_group" "backend" {
  name                  = "backend-neg"
  project               = var.project_id
  region                = var.region
  network_endpoint_type = "SERVERLESS"

  cloud_run {
    service = var.backend_service_name
  }
}

# Network Endpoint Groups for Agent backends (if multi-agent enabled)
resource "google_compute_region_network_endpoint_group" "backend_agent1" {
  count = var.enable_multi_agent ? 1 : 0
  
  name                  = "backend-agent1-neg"
  project               = var.project_id
  region                = var.region
  network_endpoint_type = "SERVERLESS"

  cloud_run {
    service = var.agent_backend_services["agent1"]
  }
}

resource "google_compute_region_network_endpoint_group" "backend_agent2" {
  count = var.enable_multi_agent ? 1 : 0
  
  name                  = "backend-agent2-neg"
  project               = var.project_id
  region                = var.region
  network_endpoint_type = "SERVERLESS"

  cloud_run {
    service = var.agent_backend_services["agent2"]
  }
}

resource "google_compute_region_network_endpoint_group" "backend_agent3" {
  count = var.enable_multi_agent ? 1 : 0
  
  name                  = "backend-agent3-neg"
  project               = var.project_id
  region                = var.region
  network_endpoint_type = "SERVERLESS"

  cloud_run {
    service = var.agent_backend_services["agent3"]
  }
}

# Backend Service for Frontend
resource "google_compute_backend_service" "frontend" {
  name                  = "frontend-backend-service"
  project               = var.project_id
  protocol              = "HTTP"
  port_name             = "http"
  timeout_sec           = 30
  load_balancing_scheme = "EXTERNAL_MANAGED"

  backend {
    group = google_compute_region_network_endpoint_group.frontend.id
  }

  log_config {
    enable      = true
    sample_rate = 1.0
  }
}

# Backend Service for Backend API
resource "google_compute_backend_service" "backend" {
  name                  = "backend-backend-service"
  project               = var.project_id
  protocol              = "HTTP"
  port_name             = "http"
  timeout_sec           = 30
  load_balancing_scheme = "EXTERNAL_MANAGED"

  backend {
    group = google_compute_region_network_endpoint_group.backend.id
  }

  log_config {
    enable      = true
    sample_rate = 1.0
  }
}

# Backend Services for Agents (if multi-agent enabled)
resource "google_compute_backend_service" "backend_agent1" {
  count = var.enable_multi_agent ? 1 : 0
  
  name                  = "backend-agent1-backend-service"
  project               = var.project_id
  protocol              = "HTTP"
  port_name             = "http"
  timeout_sec           = 30
  load_balancing_scheme = "EXTERNAL_MANAGED"

  backend {
    group = google_compute_region_network_endpoint_group.backend_agent1[0].id
  }

  log_config {
    enable      = true
    sample_rate = 1.0
  }
}

resource "google_compute_backend_service" "backend_agent2" {
  count = var.enable_multi_agent ? 1 : 0
  
  name                  = "backend-agent2-backend-service"
  project               = var.project_id
  protocol              = "HTTP"
  port_name             = "http"
  timeout_sec           = 30
  load_balancing_scheme = "EXTERNAL_MANAGED"

  backend {
    group = google_compute_region_network_endpoint_group.backend_agent2[0].id
  }

  log_config {
    enable      = true
    sample_rate = 1.0
  }
}

resource "google_compute_backend_service" "backend_agent3" {
  count = var.enable_multi_agent ? 1 : 0
  
  name                  = "backend-agent3-backend-service"
  project               = var.project_id
  protocol              = "HTTP"
  port_name             = "http"
  timeout_sec           = 30
  load_balancing_scheme = "EXTERNAL_MANAGED"

  backend {
    group = google_compute_region_network_endpoint_group.backend_agent3[0].id
  }

  log_config {
    enable      = true
    sample_rate = 1.0
  }
}

# URL Map with Path-based Routing
resource "google_compute_url_map" "default" {
  name            = "app-url-map"
  project         = var.project_id
  default_service = google_compute_backend_service.frontend.id

  host_rule {
    hosts        = ["*"]
    path_matcher = "api-matcher"
  }

  path_matcher {
    name            = "api-matcher"
    default_service = google_compute_backend_service.frontend.id

    # Backend API routes
    path_rule {
      paths   = ["/api/*"]
      service = google_compute_backend_service.backend.id
    }

    # Agent 1 API routes (if enabled)
    dynamic "path_rule" {
      for_each = var.enable_multi_agent ? [1] : []
      content {
        paths   = ["/agent1/api/*"]
        service = google_compute_backend_service.backend_agent1[0].id
      }
    }

    # Agent 2 API routes (if enabled)
    dynamic "path_rule" {
      for_each = var.enable_multi_agent ? [1] : []
      content {
        paths   = ["/agent2/api/*"]
        service = google_compute_backend_service.backend_agent2[0].id
      }
    }

    # Agent 3 API routes (if enabled)
    dynamic "path_rule" {
      for_each = var.enable_multi_agent ? [1] : []
      content {
        paths   = ["/agent3/api/*"]
        service = google_compute_backend_service.backend_agent3[0].id
      }
    }
  }
}

# HTTPS Proxy
resource "google_compute_target_https_proxy" "default" {
  name             = "app-https-proxy"
  project          = var.project_id
  url_map          = google_compute_url_map.default.id
  ssl_certificates = [google_compute_managed_ssl_certificate.default.id]
}

# Forwarding Rule (connects IP to HTTPS Proxy)
resource "google_compute_global_forwarding_rule" "default" {
  name                  = "app-forwarding-rule"
  project               = var.project_id
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "443"
  target                = google_compute_target_https_proxy.default.id
  ip_address            = google_compute_global_address.default.id
}

# ADK RAG Agent - Detailed Architecture Blueprint

This document provides a comprehensive architectural blueprint with all technical details, IPs, URLs, and configurations needed for Terraform implementation and engineering reference.

## 🏗️ Complete Architecture Diagram

```
                                    ┌─────────────────────────────────────────────────────────────┐
                                    │                      INTERNET                               │
                                    │                   (Public Access)                          │
                                    └─────────────────────┬───────────────────────────────────────┘
                                                          │
                                                          │ HTTPS (Port 443)
                                                          │
                                    ┌─────────────────────▼───────────────────────────────────────┐
                                    │              GOOGLE CLOUD LOAD BALANCER                    │
                                    │                                                             │
                                    │  Public IP: 34.36.213.78                                  │
                                    │  Domain: 34.36.213.78.nip.io                              │
                                    │  SSL Certificate: Google-managed (auto-provisioned)        │
                                    │  Protocol: HTTPS only                                      │
                                    │                                                             │
                                    │  ┌─────────────────────────────────────────────────────┐   │
                                    │  │            FORWARDING RULE                          │   │
                                    │  │  Name: frontend-forwarding-rule                     │   │
                                    │  │  IP: 34.36.213.78                                   │   │
                                    │  │  Port: 443 (HTTPS)                                  │   │
                                    │  │  Target: frontend-target-https-proxy                │   │
                                    │  └─────────────────────────────────────────────────────┘   │
                                    │                          │                                  │
                                    │  ┌─────────────────────────────────────────────────────┐   │
                                    │  │           TARGET HTTPS PROXY                        │   │
                                    │  │  Name: frontend-target-https-proxy                  │   │
                                    │  │  SSL Certificate: frontend-ssl-cert                 │   │
                                    │  │  URL Map: frontend-url-map                          │   │
                                    │  └─────────────────────────────────────────────────────┘   │
                                    │                          │                                  │
                                    │  ┌─────────────────────────────────────────────────────┐   │
                                    │  │              URL MAP                                 │   │
                                    │  │  Name: frontend-url-map                             │   │
                                    │  │  ID: 4575056165271674379                            │   │
                                    │  │                                                     │   │
                                    │  │  Path Rules:                                        │   │
                                    │  │  • "/" (default) → frontend-backend-service        │   │
                                    │  │  • "/api" → backend-backend-service                 │   │
                                    │  │  • "/api/*" → backend-backend-service               │   │
                                    │  └─────────────────────────────────────────────────────┘   │
                                    └─────────────────────┬───────────────────┬───────────────────┘
                                                          │                   │
                                                          │                   │
                                    ┌─────────────────────▼───────────────────▼───────────────────┐
                                    │                IDENTITY-AWARE PROXY (IAP)                   │
                                    │                                                             │
                                    │  OAuth Brand: projects/895727663973/brands/895727663973    │
                                    │  OAuth Client: 895727663973-1k6tu1a8vm9q4rt3gbcls8aca5m6ia7m.apps.googleusercontent.com │
                                    │  Service Account: service-895727663973@gcp-sa-iap.iam.gserviceaccount.com │
                                    │  Access Policy: domain:develom.com, user:hector@develom.com │
                                    │                                                             │
                                    │  Authentication Flow:                                       │
                                    │  1. Unauthenticated request → HTTP 302 redirect            │
                                    │  2. Google OAuth login screen                               │
                                    │  3. Domain validation (@develom.com)                       │
                                    │  4. Authenticated request forwarded to backend services     │
                                    └─────────────────────┬───────────────────┬───────────────────┘
                                                          │                   │
                                                          │                   │
                                    ┌─────────────────────▼─────────────────┐ ┌─────────────────────▼─────────────────┐
                                    │        FRONTEND BACKEND SERVICE       │ │        BACKEND BACKEND SERVICE        │
                                    │                                       │ │                                       │
                                    │  Name: frontend-backend-service       │ │  Name: backend-backend-service        │
                                    │  Protocol: HTTP                       │ │  ID: 8085438154401310765              │
                                    │  Port: 80                             │ │  Protocol: HTTP                       │
                                    │  Health Check: /                      │ │  Port: 80                             │
                                    │  IAP: Enabled                         │ │  Health Check: /                      │
                                    │  Timeout: 30s                         │ │  IAP: Enabled                         │
                                    │                                       │ │  Timeout: 30s                         │
                                    │  ┌─────────────────────────────────┐   │ │  ┌─────────────────────────────────┐   │
                                    │  │      SERVERLESS NEG             │   │ │  │      SERVERLESS NEG             │   │
                                    │  │  Name: frontend-neg             │   │ │  │  Name: backend-neg              │   │
                                    │  │  Type: SERVERLESS               │   │ │  │  Type: SERVERLESS               │   │
                                    │  │  Region: us-central1            │   │ │  │  Region: us-central1            │   │
                                    │  │  Target: Cloud Run Service      │   │ │  │  Target: Cloud Run Service      │   │
                                    │  └─────────────────────────────────┘   │ │  └─────────────────────────────────┘   │
                                    └─────────────────────┬─────────────────┘ └─────────────────────┬─────────────────┘
                                                          │                                         │
                                                          │                                         │
                                    ┌─────────────────────▼─────────────────┐ ┌─────────────────────▼─────────────────┐
                                    │         CLOUD RUN - FRONTEND          │ │         CLOUD RUN - BACKEND           │
                                    │                                       │ │                                       │
                                    │  Service Name: frontend               │ │  Service Name: backend                │
                                    │  Region: us-central1                  │ │  Region: us-central1                  │
                                    │  Project: adk-rag-agent-2025          │ │  Project: adk-rag-agent-2025          │
                                    │  Project Number: 895727663973         │ │  Project Number: 895727663973         │
                                    │                                       │ │                                       │
                                    │  Service URL:                         │ │  Service URL:                         │
                                    │  https://frontend-895727663973.       │ │  https://backend-43uf5nyn7a-uc.       │
                                    │  us-central1.run.app                  │ │  a.run.app                            │
                                    │                                       │ │                                       │
                                    │  Container Image:                     │ │  Container Image:                     │
                                    │  gcr.io/adk-rag-agent-2025/frontend  │ │  gcr.io/adk-rag-agent-2025/backend   │
                                    │                                       │ │                                       │
                                    │  Environment Variables:               │ │  Environment Variables:               │
                                    │  • NEXT_PUBLIC_BACKEND_URL=           │ │  • FRONTEND_URL=                      │
                                    │    https://34.36.213.78.nip.io       │ │    https://34.36.213.78.nip.io       │
                                    │                                       │ │                                       │
                                    │  IAM Policy:                          │ │  IAM Policy:                          │
                                    │  • roles/run.invoker:                 │ │  • roles/run.invoker:                 │
                                    │    - domain:develom.com               │ │    - domain:develom.com               │
                                    │    - user:hector@develom.com          │ │    - user:hector@develom.com          │
                                    │    - service-895727663973@gcp-sa-iap. │ │    - service-895727663973@gcp-sa-iap. │
                                    │      iam.gserviceaccount.com          │ │      iam.gserviceaccount.com          │
                                    │                                       │ │                                       │
                                    │  Port: 8080                           │ │  Port: 8000                           │
                                    │  CPU: 1                               │ │  CPU: 1                               │
                                    │  Memory: 512Mi                        │ │  Memory: 512Mi                        │
                                    │  Min Instances: 0                     │ │  Min Instances: 0                     │
                                    │  Max Instances: 100                   │ │  Max Instances: 100                   │
                                    │  Concurrency: 80                      │ │  Concurrency: 80                      │
                                    │  Timeout: 300s                        │ │  Timeout: 300s                        │
                                    │                                       │ │                                       │
                                    │  Framework: Next.js                   │ │  Framework: FastAPI                   │
                                    │  Runtime: Node.js                     │ │  Runtime: Python                      │
                                    └───────────────────────────────────────┘ └───────────────────────────────────────┘
```

## 🔧 Technical Configuration Details

### Load Balancer Components

#### Global Forwarding Rule
```yaml
name: frontend-forwarding-rule
ip_address: 34.36.213.78
ip_protocol: TCP
port_range: "443"
target: frontend-target-https-proxy
load_balancing_scheme: EXTERNAL
```

#### Target HTTPS Proxy
```yaml
name: frontend-target-https-proxy
url_map: frontend-url-map
ssl_certificates:
  - frontend-ssl-cert
```

#### SSL Certificate
```yaml
name: frontend-ssl-cert
type: MANAGED
domains:
  - 34.36.213.78.nip.io
```

#### URL Map
```yaml
name: frontend-url-map
id: "4575056165271674379"
default_service: frontend-backend-service
path_matchers:
  - name: api-matcher
    path_rules:
      - paths: ["/api", "/api/*"]
        service: backend-backend-service
```

### Backend Services

#### Frontend Backend Service
```yaml
name: frontend-backend-service
protocol: HTTP
port: 80
timeout_sec: 30
enable_cdn: false
session_affinity: NONE
locality_lb_policy: ROUND_ROBIN
backends:
  - group: frontend-neg
    balancing_mode: UTILIZATION
    capacity_scaler: 1.0
health_checks:
  - frontend-health-check
iap:
  enabled: true
  oauth2_client_id: 895727663973-1k6tu1a8vm9q4rt3gbcls8aca5m6ia7m.apps.googleusercontent.com
  oauth2_client_secret: [MANAGED_BY_GOOGLE]
```

#### Backend Backend Service
```yaml
name: backend-backend-service
id: "8085438154401310765"
protocol: HTTP
port: 80
timeout_sec: 30
enable_cdn: false
session_affinity: NONE
locality_lb_policy: ROUND_ROBIN
backends:
  - group: backend-neg
    balancing_mode: UTILIZATION
    capacity_scaler: 1.0
health_checks:
  - backend-health-check
iap:
  enabled: true
  oauth2_client_id: 895727663973-1k6tu1a8vm9q4rt3gbcls8aca5m6ia7m.apps.googleusercontent.com
  oauth2_client_secret: [MANAGED_BY_GOOGLE]
```

### Network Endpoint Groups (NEGs)

#### Frontend NEG
```yaml
name: frontend-neg
type: SERVERLESS
region: us-central1
cloud_run:
  service: frontend
  tag: [LATEST]
```

#### Backend NEG
```yaml
name: backend-neg
type: SERVERLESS
region: us-central1
cloud_run:
  service: backend
  tag: [LATEST]
```

### Cloud Run Services

#### Frontend Service
```yaml
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: frontend
  namespace: adk-rag-agent-2025
  labels:
    cloud.googleapis.com/location: us-central1
  annotations:
    run.googleapis.com/ingress: all
    run.googleapis.com/ingress-status: all
spec:
  template:
    metadata:
      annotations:
        autoscaling.knative.dev/maxScale: "100"
        autoscaling.knative.dev/minScale: "0"
        run.googleapis.com/cpu-throttling: "true"
        run.googleapis.com/execution-environment: gen2
    spec:
      containerConcurrency: 80
      timeoutSeconds: 300
      containers:
      - image: gcr.io/adk-rag-agent-2025/frontend:latest
        ports:
        - name: http1
          containerPort: 8080
        env:
        - name: NEXT_PUBLIC_BACKEND_URL
          value: "https://34.36.213.78.nip.io"
        resources:
          limits:
            cpu: "1"
            memory: "512Mi"
```

#### Backend Service
```yaml
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: backend
  namespace: adk-rag-agent-2025
  labels:
    cloud.googleapis.com/location: us-central1
  annotations:
    run.googleapis.com/ingress: all
    run.googleapis.com/ingress-status: all
spec:
  template:
    metadata:
      annotations:
        autoscaling.knative.dev/maxScale: "100"
        autoscaling.knative.dev/minScale: "0"
        run.googleapis.com/cpu-throttling: "true"
        run.googleapis.com/execution-environment: gen2
    spec:
      containerConcurrency: 80
      timeoutSeconds: 300
      containers:
      - image: gcr.io/adk-rag-agent-2025/backend:latest
        ports:
        - name: http1
          containerPort: 8000
        env:
        - name: FRONTEND_URL
          value: "https://34.36.213.78.nip.io"
        resources:
          limits:
            cpu: "1"
            memory: "512Mi"
```

### IAP Configuration

#### OAuth Brand
```yaml
name: projects/895727663973/brands/895727663973
brand_id: "895727663973"
application_title: "ADK RAG Agent"
support_email: "hector@develom.com"
```

#### OAuth Client
```yaml
name: projects/895727663973/brands/895727663973/identityAwareProxyClients/895727663973-1k6tu1a8vm9q4rt3gbcls8aca5m6ia7m.apps.googleusercontent.com
client_id: 895727663973-1k6tu1a8vm9q4rt3gbcls8aca5m6ia7m.apps.googleusercontent.com
display_name: "IAP Client for ADK RAG Agent"
```

#### IAP Service Account
```yaml
email: service-895727663973@gcp-sa-iap.iam.gserviceaccount.com
display_name: "IAP Service Account"
description: "Service account for Identity-Aware Proxy"
```

### IAM Policies

#### Frontend Service IAM
```yaml
bindings:
- members:
  - domain:develom.com
  - user:hector@develom.com
  - serviceAccount:service-895727663973@gcp-sa-iap.iam.gserviceaccount.com
  role: roles/run.invoker
```

#### Backend Service IAM
```yaml
bindings:
- members:
  - domain:develom.com
  - user:hector@develom.com
  - serviceAccount:service-895727663973@gcp-sa-iap.iam.gserviceaccount.com
  role: roles/run.invoker
```

#### IAP Access Policy
```yaml
bindings:
- members:
  - domain:develom.com
  - user:hector@develom.com
  role: roles/iap.httpsResourceAccessor
```

## 🌐 Network Flow Diagram

```
┌─────────────────┐    HTTPS/443     ┌─────────────────────────────────────┐
│   User Browser  │ ───────────────► │     Load Balancer                   │
│                 │                  │     34.36.213.78                    │
└─────────────────┘                  │     34.36.213.78.nip.io            │
                                     └─────────────────┬───────────────────┘
                                                       │
                                                       │ OAuth Check
                                                       ▼
                                     ┌─────────────────────────────────────┐
                                     │          IAP Layer                  │
                                     │   OAuth: accounts.google.com        │
                                     │   Domain: @develom.com              │
                                     └─────────────────┬───────────────────┘
                                                       │
                                                       │ Authenticated
                                                       ▼
                                     ┌─────────────────────────────────────┐
                                     │        URL Routing                  │
                                     │  "/" → Frontend                     │
                                     │  "/api/*" → Backend                 │
                                     └─────────┬───────────┬───────────────┘
                                               │           │
                                               ▼           ▼
                                     ┌─────────────┐ ┌─────────────┐
                                     │  Frontend   │ │   Backend   │
                                     │  Cloud Run  │ │  Cloud Run  │
                                     │  :8080      │ │   :8000     │
                                     └─────────────┘ └─────────────┘
```

## 📋 Terraform Resource Mapping

### Required Terraform Resources

```hcl
# Global IP Address
resource "google_compute_global_address" "default" {
  name = "frontend-ip"
}

# SSL Certificate
resource "google_compute_managed_ssl_certificate" "default" {
  name = "frontend-ssl-cert"
  managed {
    domains = ["34.36.213.78.nip.io"]
  }
}

# Backend Services
resource "google_compute_backend_service" "frontend" {
  name        = "frontend-backend-service"
  protocol    = "HTTP"
  port_name   = "http"
  timeout_sec = 30
  
  backend {
    group = google_compute_region_network_endpoint_group.frontend.id
  }
  
  iap {
    oauth2_client_id     = google_iap_client.project_client.client_id
    oauth2_client_secret = google_iap_client.project_client.secret
  }
}

resource "google_compute_backend_service" "backend" {
  name        = "backend-backend-service"
  protocol    = "HTTP"
  port_name   = "http"
  timeout_sec = 30
  
  backend {
    group = google_compute_region_network_endpoint_group.backend.id
  }
  
  iap {
    oauth2_client_id     = google_iap_client.project_client.client_id
    oauth2_client_secret = google_iap_client.project_client.secret
  }
}

# Network Endpoint Groups
resource "google_compute_region_network_endpoint_group" "frontend" {
  name                  = "frontend-neg"
  network_endpoint_type = "SERVERLESS"
  region                = "us-central1"
  
  cloud_run {
    service = google_cloud_run_service.frontend.name
  }
}

resource "google_compute_region_network_endpoint_group" "backend" {
  name                  = "backend-neg"
  network_endpoint_type = "SERVERLESS"
  region                = "us-central1"
  
  cloud_run {
    service = google_cloud_run_service.backend.name
  }
}

# URL Map
resource "google_compute_url_map" "default" {
  name            = "frontend-url-map"
  default_service = google_compute_backend_service.frontend.id
  
  path_matcher {
    name            = "api-matcher"
    default_service = google_compute_backend_service.frontend.id
    
    path_rule {
      paths   = ["/api", "/api/*"]
      service = google_compute_backend_service.backend.id
    }
  }
}

# Target HTTPS Proxy
resource "google_compute_target_https_proxy" "default" {
  name             = "frontend-target-https-proxy"
  url_map          = google_compute_url_map.default.id
  ssl_certificates = [google_compute_managed_ssl_certificate.default.id]
}

# Global Forwarding Rule
resource "google_compute_global_forwarding_rule" "default" {
  name       = "frontend-forwarding-rule"
  target     = google_compute_target_https_proxy.default.id
  port_range = "443"
  ip_address = google_compute_global_address.default.address
}

# Cloud Run Services
resource "google_cloud_run_service" "frontend" {
  name     = "frontend"
  location = "us-central1"
  
  template {
    spec {
      containers {
        image = "gcr.io/adk-rag-agent-2025/frontend:latest"
        ports {
          container_port = 8080
        }
        env {
          name  = "NEXT_PUBLIC_BACKEND_URL"
          value = "https://34.36.213.78.nip.io"
        }
      }
    }
  }
}

resource "google_cloud_run_service" "backend" {
  name     = "backend"
  location = "us-central1"
  
  template {
    spec {
      containers {
        image = "gcr.io/adk-rag-agent-2025/backend:latest"
        ports {
          container_port = 8000
        }
        env {
          name  = "FRONTEND_URL"
          value = "https://34.36.213.78.nip.io"
        }
      }
    }
  }
}

# IAP Configuration
resource "google_iap_brand" "project_brand" {
  support_email     = "hector@develom.com"
  application_title = "ADK RAG Agent"
  project           = "adk-rag-agent-2025"
}

resource "google_iap_client" "project_client" {
  display_name = "IAP Client for ADK RAG Agent"
  brand        = google_iap_brand.project_brand.name
}

# IAM Policies
resource "google_cloud_run_service_iam_binding" "frontend_invoker" {
  location = google_cloud_run_service.frontend.location
  service  = google_cloud_run_service.frontend.name
  role     = "roles/run.invoker"
  
  members = [
    "domain:develom.com",
    "user:hector@develom.com",
    "serviceAccount:service-895727663973@gcp-sa-iap.iam.gserviceaccount.com"
  ]
}

resource "google_cloud_run_service_iam_binding" "backend_invoker" {
  location = google_cloud_run_service.backend.location
  service  = google_cloud_run_service.backend.name
  role     = "roles/run.invoker"
  
  members = [
    "domain:develom.com",
    "user:hector@develom.com",
    "serviceAccount:service-895727663973@gcp-sa-iap.iam.gserviceaccount.com"
  ]
}

resource "google_iap_web_iam_binding" "binding" {
  project = "adk-rag-agent-2025"
  role    = "roles/iap.httpsResourceAccessor"
  
  members = [
    "domain:develom.com",
    "user:hector@develom.com"
  ]
}
```

## 🔍 Verification Commands

### Check Load Balancer Status
```bash
# Global IP
gcloud compute addresses describe frontend-ip --global

# SSL Certificate
gcloud compute ssl-certificates describe frontend-ssl-cert --global

# Backend Services
gcloud compute backend-services describe frontend-backend-service --global
gcloud compute backend-services describe backend-backend-service --global

# URL Map
gcloud compute url-maps describe frontend-url-map --global
```

### Check Cloud Run Services
```bash
# Frontend Service
gcloud run services describe frontend --region=us-central1

# Backend Service
gcloud run services describe backend --region=us-central1

# Service URLs
gcloud run services list --region=us-central1
```

### Check IAP Configuration
```bash
# IAP Status
gcloud iap web get-iam-policy --resource-type=backend-services --service=frontend-backend-service
gcloud iap web get-iam-policy --resource-type=backend-services --service=backend-backend-service

# OAuth Clients
gcloud iap oauth-clients list projects/895727663973/brands/895727663973
```

---

*This blueprint provides all technical details needed for Terraform implementation and infrastructure replication.*

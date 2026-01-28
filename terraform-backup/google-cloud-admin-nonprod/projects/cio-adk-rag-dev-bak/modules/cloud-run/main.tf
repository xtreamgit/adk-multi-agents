# Cloud Run Services Module
# Deploys Frontend and Backend services to Cloud Run

# Backend Service (Primary)
resource "google_cloud_run_v2_service" "backend" {
  name     = "backend"
  location = var.region
  project  = var.project_id

  template {
    service_account = var.backend_service_account
    
    scaling {
      min_instance_count = var.backend_min_instances
      max_instance_count = var.backend_max_instances
    }
    
    containers {
      image = var.backend_image
      
      resources {
        limits = {
          cpu    = var.backend_cpu
          memory = var.backend_memory
        }
      }
      
      # Environment variables
      dynamic "env" {
        for_each = merge(var.backend_env_vars, {
          ROOT_PATH = ""
          ACCOUNT_ENV = "default"
        })
        content {
          name  = env.key
          value = env.value
        }
      }
    }
    
    # Container concurrency
    max_instance_request_concurrency = 80
  }
  
  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }
  
  labels = {
    app      = "adk-rag-agent"
    role     = "backend"
    security = "iap-protected"
    agent    = "default"
  }
}

# Backend Service IAM - Allow Load Balancer
resource "google_cloud_run_v2_service_iam_member" "backend_invoker" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.backend.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Backend Agent 1 Service (if multi-agent enabled)
resource "google_cloud_run_v2_service" "backend_agent1" {
  count = var.enable_multi_agent ? 1 : 0
  
  name     = "backend-agent1"
  location = var.region
  project  = var.project_id

  template {
    service_account = var.agent_service_accounts["agent1"]
    
    scaling {
      min_instance_count = var.backend_min_instances
      max_instance_count = var.backend_max_instances
    }
    
    containers {
      image = var.backend_image
      
      resources {
        limits = {
          cpu    = var.backend_cpu
          memory = var.backend_memory
        }
      }
      
      dynamic "env" {
        for_each = merge(var.backend_env_vars, {
          ROOT_PATH = "/agent1"
          ACCOUNT_ENV = "agent1"
        })
        content {
          name  = env.key
          value = env.value
        }
      }
    }
    
    max_instance_request_concurrency = 80
  }
  
  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }
  
  labels = {
    app      = "adk-rag-agent"
    role     = "backend"
    security = "iap-protected"
    agent    = "agent1"
  }
}

resource "google_cloud_run_v2_service_iam_member" "backend_agent1_invoker" {
  count    = var.enable_multi_agent ? 1 : 0
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.backend_agent1[0].name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Backend Agent 2 Service
resource "google_cloud_run_v2_service" "backend_agent2" {
  count = var.enable_multi_agent ? 1 : 0
  
  name     = "backend-agent2"
  location = var.region
  project  = var.project_id

  template {
    service_account = var.agent_service_accounts["agent2"]
    
    scaling {
      min_instance_count = var.backend_min_instances
      max_instance_count = var.backend_max_instances
    }
    
    containers {
      image = var.backend_image
      
      resources {
        limits = {
          cpu    = var.backend_cpu
          memory = var.backend_memory
        }
      }
      
      dynamic "env" {
        for_each = merge(var.backend_env_vars, {
          ROOT_PATH = "/agent2"
          ACCOUNT_ENV = "agent2"
        })
        content {
          name  = env.key
          value = env.value
        }
      }
    }
    
    max_instance_request_concurrency = 80
  }
  
  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }
  
  labels = {
    app      = "adk-rag-agent"
    role     = "backend"
    security = "iap-protected"
    agent    = "agent2"
  }
}

resource "google_cloud_run_v2_service_iam_member" "backend_agent2_invoker" {
  count    = var.enable_multi_agent ? 1 : 0
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.backend_agent2[0].name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Backend Agent 3 Service
resource "google_cloud_run_v2_service" "backend_agent3" {
  count = var.enable_multi_agent ? 1 : 0
  
  name     = "backend-agent3"
  location = var.region
  project  = var.project_id

  template {
    service_account = var.agent_service_accounts["agent3"]
    
    scaling {
      min_instance_count = var.backend_min_instances
      max_instance_count = var.backend_max_instances
    }
    
    containers {
      image = var.backend_image
      
      resources {
        limits = {
          cpu    = var.backend_cpu
          memory = var.backend_memory
        }
      }
      
      dynamic "env" {
        for_each = merge(var.backend_env_vars, {
          ROOT_PATH = "/agent3"
          ACCOUNT_ENV = "agent3"
        })
        content {
          name  = env.key
          value = env.value
        }
      }
    }
    
    max_instance_request_concurrency = 80
  }
  
  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }
  
  labels = {
    app      = "adk-rag-agent"
    role     = "backend"
    security = "iap-protected"
    agent    = "agent3"
  }
}

resource "google_cloud_run_v2_service_iam_member" "backend_agent3_invoker" {
  count    = var.enable_multi_agent ? 1 : 0
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.backend_agent3[0].name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Frontend Service
resource "google_cloud_run_v2_service" "frontend" {
  name     = "frontend"
  location = var.region
  project  = var.project_id

  template {
    service_account = var.frontend_service_account
    
    scaling {
      min_instance_count = var.frontend_min_instances
      max_instance_count = var.frontend_max_instances
    }
    
    containers {
      image = var.frontend_image
      
      resources {
        limits = {
          cpu    = var.frontend_cpu
          memory = var.frontend_memory
        }
      }
      
      env {
        name  = "NODE_ENV"
        value = "production"
      }
      
      env {
        name  = "PORT"
        value = "3000"
      }
    }
    
    max_instance_request_concurrency = 80
  }
  
  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }
  
  labels = {
    app      = "adk-rag-agent"
    role     = "frontend"
    security = "iap-protected"
  }
}

# Frontend Service IAM - Allow Load Balancer
resource "google_cloud_run_v2_service_iam_member" "frontend_invoker" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.frontend.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

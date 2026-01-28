# Artifact Registry Module
# Creates Docker repository for container images

resource "google_artifact_registry_repository" "docker_repo" {
  location      = var.region
  repository_id = var.repository_id
  description   = "Docker repository for Cloud Run container images"
  format        = "DOCKER"
  
  labels = {
    managed-by = "terraform"
    purpose    = "cloud-run-images"
  }
}

# IAM binding to allow Cloud Build to push images
resource "google_artifact_registry_repository_iam_member" "cloudbuild_writer" {
  project    = var.project_id
  location   = google_artifact_registry_repository.docker_repo.location
  repository = google_artifact_registry_repository.docker_repo.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${data.google_project.project.number}@cloudbuild.gserviceaccount.com"
}

data "google_project" "project" {
  project_id = var.project_id
}


# Remove basic roles from project
resource "google_project_iam_binding" "remove-editor-role" {
  project = var.common.project_id
  role    = "roles/editor"
  members = []
}
resource "google_project_iam_binding" "remove-owner-role" {
  project = var.common.project_id
  role    = "roles/owner"
  members = []
}
resource "google_project_iam_binding" "remove-viewer-role" {
  project = var.common.project_id
  role    = "roles/viewer"
  members = []
}
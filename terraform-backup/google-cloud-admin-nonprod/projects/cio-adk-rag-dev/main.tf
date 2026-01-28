# GCP Project resource
# Creates the GCP project with organization settings and labels
resource "google_project" "project" {
  auto_create_network = false
  billing_account     = module.usfs_info.billing_account_id_secret
  folder_id           = var.project_folder

  labels = {
    code-management = "terraform"
    dashboard_group = var.project_dashboard_label
  }

  name       = var.project_name
  project_id = var.project_id
}

# Project Services module
# Enables required APIs for the project
# https://registry.terraform.io/modules/terraform-google-modules/project-factory/google/latest/submodules/project_services
module "project-services" {
  depends_on    = [google_project.project]
  source        = "terraform-google-modules/project-factory/google//modules/project_services"
  version       = "~> 17.0"
  project_id    = google_project.project.project_id
  activate_apis = local.apis_list
}

# Roles module
# Creates custom IAM roles for the project
module "roles" {
  depends_on              = [google_project.project]
  source                  = "./modules/roles"
  common                  = local.common_info
  project_permissions_map = local.project_permissions_map
}

# Service Account module
# Creates service accounts for project operations
module "service_account" {
  depends_on = [google_project.project, module.project-services]
  source     = "./modules/service_account"
  common     = local.common_info
}

# IAM module
# Binds service accounts and groups to roles
module "iam" {
  project_id              = var.project_id
  depends_on              = [google_project.project, module.roles, module.service_account]
  source                  = "./modules/iam"
  common                  = local.common_info
  iam_binding_expiration  = local.iam_binding_expiration
  project_number          = google_project.project.number
  project_permissions_map = local.project_permissions_map
}

# Buckets module
# Creates GCS buckets for project storage
module "buckets" {
  depends_on = [google_project.project, module.roles]
  source     = "./modules/buckets"
  common     = local.common_info
  bucket_info = local.bucket_info
}

# Compute module
# Creates VPCs, VMs, and related compute resources
module "compute" {
  depends_on = [google_project.project, module.project-services, module.roles, module.service_account]
  source     = "./modules/compute"
  common     = local.common_info
  vm_info    = local.vm_info
  vpc_info   = local.vpc_info
}

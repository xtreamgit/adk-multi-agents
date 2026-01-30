# Google provider
provider "google" {
  project = module.usfs_info.admin_project_id
  region  = local.common_info.project_region
}

# Google Beta provider
provider "google-beta" {
  project = module.usfs_info.admin_project_id
  region  = local.common_info.project_region
}

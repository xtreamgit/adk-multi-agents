# Local values for module configuration
# These aggregate variables and module outputs for cleaner module calls

locals {
  # Project APIs - combines custom roles requirements with project-specific APIs
  apis_list = concat(
    module.usfs_custom_roles.blank_api_listing, 
    var.project_apis,
  )

  # Common project information passed to all modules
  common_info = {
    project_id            = var.project_id
    project_name          = var.project_name
    project_region        = coalesce(var.project_region, module.usfs_info.default_gcp_region)
    project_backup_region = coalesce(var.project_backup_region, module.usfs_info.default_gcp_backup_region)
  }

  # Bucket configuration for storage module
  bucket_info = {
    bucket_apply_life_cycle_rules   = var.bucket_apply_life_cycle_rules
    bucket_create_backup            = var.bucket_create_backup
    bucket_force_destroy            = var.bucket_force_destroy
    bucket_public_access_prevention = var.bucket_public_access_prevention
    bucket_soft_delete_seconds      = var.bucket_soft_delete_seconds
    bucket_name_list                = var.bucket_name_list
    bucket_versioning               = var.bucket_versioning
  }

  # IAM binding expiration (usfs_info takes precedence over project setting)
  iam_binding_expiration = try(coalesce(module.usfs_info.iam_binding_expiration, var.project_iam_binding_expiration), null)

  # Project permissions map defines roles and assignments for groups
  project_permissions_map = {
    "user" = {
      email_list     = var.group_user_id_list
      cust_role_list = [
        # UPDATE: Add custom role names as needed
      ]
      gcp_role_list = [
        # UPDATE: Add GCP built-in role names as needed
      ]
    }
    # Additional group role mappings can be added here (e.g., "viewer", "sa_compute")
  }

  # VM configuration for compute module
  vm_info = {
    vm_create_list            = var.vm_create_list
    vm_map                    = var.vm_map
    vm_source_image           = var.vm_source_image
    vm_initial_boot_disk_size = var.vm_initial_boot_disk_size
    vm_initial_type           = var.vm_initial_type
  }

  # VPC configuration for compute module
  vpc_info = {
    vpc_private_access = var.vpc_private_access
  }
}

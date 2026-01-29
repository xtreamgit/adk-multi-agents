
# create random id
resource "random_string" "bucket" {
  length      = 6
  lower       = true
  min_lower   = 3
  numeric     = true
  min_numeric = 3
  upper       = false
  special     = false
}

# create storage bucket 01
resource "google_storage_bucket" "storage_buckets" {
    for_each                    = toset(var.bucket_info.bucket_name_list)
    default_event_based_hold    = false
    force_destroy               = var.bucket_info.bucket_force_destroy
    labels                      = {}
    location                    = var.bucket_info.bucket_create_backup ? "US" : var.common.project_region
    name                        = "${each.value}-${random_string.bucket.result}" 
    public_access_prevention    = var.bucket_info.bucket_public_access_prevention
    project                     = var.common.project_id
    requester_pays              = false
    storage_class               = "STANDARD"
    uniform_bucket_level_access = true

    # autoclass
    autoclass {
      enabled                   = true
    }

    # soft delete policy
    soft_delete_policy {
      retention_duration_seconds = var.bucket_info.bucket_soft_delete_seconds
    }

    # custom placement config
    dynamic "custom_placement_config" {
      for_each = var.bucket_info.bucket_create_backup == true ? [1] : []
      content {
        data_locations = [var.common.project_region, var.common.project_backup_region]
      }
    }

    # dynamic life cycle rule 1
    dynamic "lifecycle_rule" {
      for_each = var.bucket_info.bucket_apply_life_cycle_rules == true ? [1] : []
      content {
        action {
          type = "Delete"
        }
        condition {
          age                        = 0
          days_since_custom_time     = 0
          days_since_noncurrent_time = 0
          matches_storage_class      = []
          num_newer_versions         = 1
          with_state                 = "ANY"
        }
      }
    }

    # dynamic life cycle rule 2
    dynamic "lifecycle_rule" {
      for_each = var.bucket_info.bucket_apply_life_cycle_rules == true ? [1] : []
      content {
        action {
          type = "Delete"
        }
        condition {
          age                        = 0
          days_since_custom_time     = 0
          days_since_noncurrent_time = 30
          matches_storage_class      = []
          num_newer_versions         = 0
          with_state                 = "ANY"
        }
      }
    }

    # versioning
    versioning {
        enabled = var.bucket_info.bucket_versioning
    }
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# create storage bucket policy
data "google_iam_policy" "storage_bucket_policy" {

  # # admin binding - admin permissions established at USFS folder level
  # binding {
  #   role = "roles/storage.admin"
  #   members = [ 
  #    var.admin_group_id
  #    ]
  #   } 

  # # user binding
  # dynamic "binding" {
  #   for_each = var.common.group_user_id_list == null ? [] : [1]
  #   content {
  #     role = var.common.role_user_id
  #     members = var.common.group_user_id_list
  #   }
  # }   

  # # viewer binding (if needed)
  # dynamic "binding" {
  #   for_each = var.common.group_viewer_id_list == null ? [] : [1]
  #   content {
  #     role = var.common.role_viewer_id
  #     members = var.common.group_viewer_id_list
  #   }
  # }

  # public binding (if needed)
  dynamic "binding" {
    for_each = var.bucket_info.bucket_public_access_prevention == "inherited" ? [1] : []
    content {
      role = "roles/storage.legacyBucketReader"
      members = [
        "allUsers"
      ]
    }
  }
  dynamic "binding" {
    for_each = var.bucket_info.bucket_public_access_prevention == "inherited" ? [1] : []
    content {
      role = "roles/storage.legacyObjectReader"
      members = [
        "allUsers"
      ]
    }
  }
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# assign storage bucket policy to storage bucket
resource "google_storage_bucket_iam_policy" "apply_storage_bucket_policy" {
  for_each = toset(var.bucket_info.bucket_name_list)
  bucket = google_storage_bucket.storage_buckets[each.value].self_link
  policy_data = data.google_iam_policy.storage_bucket_policy.policy_data
}

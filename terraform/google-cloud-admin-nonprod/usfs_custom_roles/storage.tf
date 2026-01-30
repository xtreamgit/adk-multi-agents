
# Role information
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

output "usfs_storage_user" {
  value = {
    name        = "USFSStorageUser"
    out_name    = "usfs_storage_user"
    disp_name   = "USFS Storage User"
    desc        = "USFS Storage User"
    gcp_role = "roles/storage.objectUser"
    perms = [
      "orgpolicy.policy.get",
      "resourcemanager.projects.get",
      # "resourcemanager.projects.list",      # not applicable at project level
      "storage.folders.create",
      "storage.folders.delete",
      "storage.folders.get",
      "storage.folders.list",
      "storage.folders.rename",
      # "storage.managedFolders.create",      # not using managed folders
      # "storage.managedFolders.delete",      # not using managed folders
      # "storage.managedFolders.get",         # not using managed folders
      # "storage.managedFolders.list",        # not using managed folders
      "storage.multipartUploads.abort",
      "storage.multipartUploads.create",
      "storage.multipartUploads.list",
      "storage.multipartUploads.listParts",
      "storage.objects.create",
      "storage.objects.delete",
      "storage.objects.get",
      "storage.objects.list",
      "storage.objects.restore",
      "storage.objects.update",

      # Custom add-ons
      "storage.buckets.get",
      "storage.buckets.getIamPolicy",
      "storage.buckets.getObjectInsights",
      "storage.buckets.list",
      "storage.buckets.listEffectiveTags",
      "storage.buckets.listTagBindings",
      "storage.objects.getIamPolicy",
    ]
  }
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

output "usfs_storage_viewer" {
  value = {
    name    = "USFSStorageViewer"
    out_name = "usfs_storage_viewer"
    disp_name = "USFS Storage Viewer"
    desc = "USFS Storage Viewer"
    gcp_role = "roles/storage.objectViewer"
    perms = [
      "resourcemanager.projects.get",
      # "resourcemanager.projects.list",      # not applicable at project level
      "storage.folders.get",
      "storage.folders.list",
      # "storage.managedFolders.get",         # not using managed folders
      # "storage.managedFolders.list",        # not using managed folders
      "storage.objects.get",
      "storage.objects.list",

      # Custom add-ons
      "storage.buckets.get",
      "storage.buckets.list",   
    ]
  }
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


# Role information
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

output "usfs_ee_writer" {
    value = {
        name    = "USFSEEWriter"
        out_name = "usfs_ee_writer"
        disp_name = "USFS EE Writer"
        desc = "USFS Earth Engine Resource Writer"
        gcp_role = "roles/earthengine.writer"
        perms = [
            "earthengine.assets.create",
            "earthengine.assets.delete",
            "earthengine.assets.get",
            "earthengine.assets.getIamPolicy",
            "earthengine.assets.list",
            "earthengine.assets.update",
            "earthengine.computations.create",
            "earthengine.config.get",
            "earthengine.config.update",
            "earthengine.exports.create",
            "earthengine.featureviews.create",
            "earthengine.filmstripthumbnails.create",
            "earthengine.filmstripthumbnails.get",
            "earthengine.imports.create",
            "earthengine.maps.create",
            "earthengine.maps.get",
            "earthengine.operations.delete",
            "earthengine.operations.get",
            "earthengine.operations.list",
            "earthengine.operations.update",
            "earthengine.tables.create",
            "earthengine.tables.get",
            "earthengine.thumbnails.create",
            "earthengine.thumbnails.get",
            "earthengine.videothumbnails.create",
            "earthengine.videothumbnails.get",
            "resourcemanager.projects.get",
            # "resourcemanager.projects.list",      # not applicable at project level
        ]
  }
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

output "usfs_ee_appspublisher" {
    value = {
        name    = "USFSEEAppsPublisher"
        out_name = "usfs_ee_appspublisher"
        disp_name = "USFS EE AppsPublisher"
        desc = "USFS Earth Engine Apps Publisher"
        gcp_role = "roles/earthengine.appsPublisher"
        perms = [
            "iam.serviceAccounts.create",
            "iam.serviceAccounts.disable",
            "iam.serviceAccounts.enable",
            "iam.serviceAccounts.get",
            "iam.serviceAccounts.getIamPolicy",
            "iam.serviceAccounts.setIamPolicy",
            "resourcemanager.projects.get",
            # "resourcemanager.projects.list",      # not applicable at project level
        ]
  }
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

output "usfs_ee_viewer" {
    value = {
        name    = "USFSEEViewer"
        out_name = "usfs_ee_viewer"
        disp_name = "USFS EE Viewer"
        desc = "USFS Earth Engine Resource Viewer"
        gcp_role = "roles/earthengine.viewer"
        perms = [
            "earthengine.assets.get",
            "earthengine.assets.getIamPolicy",
            "earthengine.assets.list",
            "earthengine.computations.create",
            "earthengine.config.get",
            "earthengine.filmstripthumbnails.get",
            "earthengine.maps.get",
            "earthengine.operations.get",
            "earthengine.operations.list",
            "earthengine.tables.get",
            "earthengine.thumbnails.get",
            "earthengine.videothumbnails.get",
            "resourcemanager.projects.get",
            # "resourcemanager.projects.list"      # not applicable at project level
        ]
  }
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

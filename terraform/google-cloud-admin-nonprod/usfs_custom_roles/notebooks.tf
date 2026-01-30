
# Role information
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

output "usfs_notebooks_manager" {
  value = {
    name    = "USFSNotebooksManager"
    out_name = "usfs_notebooks_manager"
    disp_name = "USFS Notebooks Manager"
    desc = "USFS Notebooks Manager"
    gcp_role = "custom role"
    perms = [
        "notebooks.instances.delete",
        "notebooks.instances.reset",
        "notebooks.instances.start",
        "notebooks.instances.stop",
        "notebooks.instances.update",
        "notebooks.runtimes.delete",
        "notebooks.runtimes.reset",
        "notebooks.runtimes.start",
        "notebooks.runtimes.stop",
        "notebooks.runtimes.update",
        "notebooks.schedules.delete",
        "notebooks.schedules.create",
        "notebooks.schedules.delete",
        "notebooks.schedules.get",
        "notebooks.schedules.getIamPolicy",
        "notebooks.schedules.list",
        "resourcemanager.projects.get",
    ]
  }
}

output "usfs_notebooks_start_stop" {
  value = {
    name    = "USFSNotebooksStartStop"
    out_name = "usfs_notebooks_start_stop"
    disp_name = "USFS Notebooks Start Stop"
    desc = "USFS Notebooks Start Stop"
    gcp_role = "custom role"
    perms = [
        "notebooks.instances.start",
        "notebooks.instances.stop",
        "notebooks.runtimes.start",
        "notebooks.runtimes.stop",
    ]
  }
}
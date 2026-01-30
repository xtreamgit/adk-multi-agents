# Role information
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

output "usfs_project_billing_viewer" {
  value = {
    name        = "USFSProjectBillingViewer"
    out_name    = "usfs_project_billing_viewer"
    disp_name   = "USFS Project Billing Viewer"
    desc        = "USFS Project Billing Viewer"
    gcp_role    = "custom role"
    perms = [
        "billing.resourceCosts.get",
        "resourcemanager.projects.get",
    ]
  }
}
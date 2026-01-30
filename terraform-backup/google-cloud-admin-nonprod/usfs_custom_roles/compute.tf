
# Role information
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

output "usfs_compute_instancemanager" {
  value = {
    name    = "USFSComputeInstanceManager"
    out_name = "usfs_compute_instancemanager"
    disp_name = "USFS Compute Instance Manager"
    desc = "USFS Compute Instance Manager"
    gcp_role = "custom role"
    perms = [
        "compute.instances.get",
        "compute.instances.getEffectiveFirewalls",
        "compute.instances.getGuestAttributes",
        "compute.instances.getIamPolicy",
        "compute.instances.getScreenshot",
        "compute.instances.getSerialPortOutput",
        "compute.instances.getShieldedInstanceIdentity",
        "compute.instances.getShieldedVmIdentity",
        "compute.instances.list",
        "compute.instances.listEffectiveTags",
        "compute.instances.listReferrers",
        "compute.instances.listTagBindings",
        "compute.instances.reset",
        "compute.instances.resume",
        "compute.instances.start",
        "compute.instances.stop",
        "compute.instances.suspend",
        "compute.instances.update",
    ]
  }
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

output "usfs_compute_instances_setmetadata" {
  value = {
    name    = "USFSComputeInstancesSetMetadata"
    out_name = "usfs_compute_instances_setmetadata"
    disp_name = "USFS Compute Instances Set Metadata"
    desc = "USFS Compute Instances Set Metadata"
    gcp_role = "custom role"
    perms = [
      "compute.instances.setMetadata",
    ]
  }
}
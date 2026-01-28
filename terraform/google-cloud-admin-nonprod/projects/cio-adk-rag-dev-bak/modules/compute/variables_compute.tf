# usfs info
module "usfs_info" {
  source = "../../../../usfs_info"
}

# common variables
variable "common" {
    type = object({
      # Project information
      project_id                      = string
      project_name                    = string
      project_region                  = string
      project_backup_region           = string
    })
}

# vpc information variables
variable "vm_info" {
    type = object({
      vm_create_list                  = list(string)

      vm_map                          = map(object({
        vm_machine_type               = string,       # machine type
        vm_bd_image                   = string,       # boot disk image
        vm_bd_size                    = number,       # boot disk size
      }))

      vm_source_image                 = string
      vm_initial_boot_disk_size       = number
      vm_initial_type                 = string
    })
}

# vpc information variables
variable "vpc_info" {
    type = object({
      vpc_private_access             = bool
    })
}

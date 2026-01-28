
output "iam_binding_expiration" {value = var.iam_binding_expiration}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# IAM binding expiration map
variable "iam_binding_expiration" {
  description = "Map of IAM binding expiration parameters."
  type = object({
    title       = string,
    description = string,
    timestamp   = string,
  })
  default = null
  # default = {
  #   title       = "expires_on_2024_12_23"
  #   description = "Expiring at midnight of 2024-12-23"
  #   timestamp   = "2024-12-23T00:00:00Z"
  # }
}

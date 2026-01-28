
# The new USDA RAS EP FS profile uses the IP range: FS Elevated privilege 199.130.132.0 /25 
# but when it goes to the internet they NAT to another range: outbound public IP 
# Range: 199.142.52.0/22 (New definition provided by the department, replaces the old one)

# The following is what should be allowed for both IPv4 and IPv6 IPs: 

# # IPv4: 
# # FS Offices and Data Center IPs 
# "166.2.0.0/15",
# "166.4.0.0/14",
# "199.131.0.0/16",
# "165.221.40.0/22",
# "165.221.108.0/24",
# "170.144.0.0/16",
# # DISC NAG: 
# "199.130.132.0/25",
# "199.142.52.0/22",   # NEW
# "199.142.54.0/23",   # OLD - REMOVE
# # IPv6: 
# "2600:1200::/24", 

output "usda_ipv4_allowed_ranges" {value = var.usda_ipv4_allowed_ranges}
output "usda_ipv6_allowed_ranges" {value = var.usda_ipv6_allowed_ranges}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

variable "usda_ipv4_allowed_ranges" {
  description = "USDA IPv4 allowed ranges."
  type        = list(string)
  default     = [
    # IPv4: 
    # FS Offices and Data Center IPs 
    "166.2.0.0/15",
    "166.4.0.0/14",
    "199.131.0.0/16",
    "165.221.40.0/22",
    "165.221.108.0/24",
    "170.144.0.0/16",
    # DISC NAG: 
    "199.130.132.0/25",
    "199.142.52.0/22",
  ]
}

variable "usda_ipv6_allowed_ranges" {
  description = "USDA IPv6 allowed ranges."
  type        = list(string)
  default     = [
    # IPv6: 
    "2600:1200::/24", 
  ]
}
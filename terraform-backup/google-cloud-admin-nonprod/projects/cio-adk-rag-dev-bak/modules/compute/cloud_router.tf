
# https://cloud.google.com/firewall/docs/quickstarts/configure-nwfwpolicy-fqdn-egress
# https://medium.com/google-cloud/gcp-how-to-deploy-cloud-nat-with-terraform-44745a4daaa8

# https://stackoverflow.com/questions/74455063/what-exactly-are-nat-gateway-and-internet-gateway-on-aws

# create cloud router
resource "google_compute_router" "router" {
  project = var.common.project_id
  name    = "nat-router"
  network = google_compute_network.vpc.name
  region  = var.common.project_region
}

# create nat gateway
resource "google_compute_router_nat" "nat" {
  project                            = var.common.project_id
  name                               = "my-router-nat"
  router                             = google_compute_router.router.name
  region                             = google_compute_router.router.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}
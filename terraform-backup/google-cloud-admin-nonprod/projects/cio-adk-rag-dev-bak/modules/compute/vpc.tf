
# Create vpc
resource "google_compute_network" "vpc" {
  project                 = var.common.project_id 
  name                    = "vpc-${var.common.project_id}"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

# Create subnetwork
resource "google_compute_subnetwork" "vpc_subnet" {
  project       = var.common.project_id
  name          = "subnet-${var.common.project_name}"
  region        = var.common.project_region
  network       = google_compute_network.vpc.self_link
  ip_cidr_range = "10.1.0.0/24"                               # what should this be set to?
  private_ip_google_access = var.vpc_info.vpc_private_access

  log_config {
    aggregation_interval = "INTERVAL_10_MIN"        # INTERVAL_5_SEC, INTERVAL_30_SEC, INTERVAL_1_MIN, INTERVAL_5_MIN, INTERVAL_10_MIN, INTERVAL_15_MIN
    flow_sampling        = 0.5                      # sampling rate, 0.0 = no logs, 1.0 = all logs, 0.5 = half of all logs
    metadata             = "INCLUDE_ALL_METADATA"   # EXCLUDE_ALL_METADATA, INCLUDE_ALL_METADATA, CUSTOM_METADATA.
    # metadata fields listed here: https://cloud.google.com/vpc/docs/about-flow-logs-records#record_format
    # metadata_fields      = []                     # list of metadata fields if metadata = CUSTOM_METADATA
    # create filter: https://cloud.google.com/vpc/docs/about-flow-logs-records#filtering
    # filter_expr = ""
  }
}




# Sources
# https://medium.com/terraform-using-google-cloud-platform/terraform-for-gcp-how-to-create-firewall-rule-480c794ecc65#id_token=eyJhbGciOiJSUzI1NiIsImtpZCI6IjBlMzQ1ZmQ3ZTRhOTcyNzFkZmZhOTkxZjVhODkzY2QxNmI4ZTA4MjciLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJodHRwczovL2FjY291bnRzLmdvb2dsZS5jb20iLCJhenAiOiIyMTYyOTYwMzU4MzQtazFrNnFlMDYwczJ0cDJhMmphbTRsamRjbXMwMHN0dGcuYXBwcy5nb29nbGV1c2VyY29udGVudC5jb20iLCJhdWQiOiIyMTYyOTYwMzU4MzQtazFrNnFlMDYwczJ0cDJhMmphbTRsamRjbXMwMHN0dGcuYXBwcy5nb29nbGV1c2VyY29udGVudC5jb20iLCJzdWIiOiIxMDM4ODQzMDkzODM5NDg2NzcyOTgiLCJoZCI6InVzZGEuZ292IiwiZW1haWwiOiJhbmRyZXcuc3RyYXR0b25AdXNkYS5nb3YiLCJlbWFpbF92ZXJpZmllZCI6dHJ1ZSwibmJmIjoxNzIxMzU0NTAxLCJuYW1lIjoiQW5kcmV3IFN0cmF0dG9uIiwicGljdHVyZSI6Imh0dHBzOi8vbGgzLmdvb2dsZXVzZXJjb250ZW50LmNvbS9hL0FDZzhvY0xUU0ZmNEZra1ZGVy1IbXZCWTVDTl8xdlZQbFdzei1vRkRndEpFb0ZaaVFjTVNKUT1zOTYtYyIsImdpdmVuX25hbWUiOiJBbmRyZXciLCJmYW1pbHlfbmFtZSI6IlN0cmF0dG9uIiwiaWF0IjoxNzIxMzU0ODAxLCJleHAiOjE3MjEzNTg0MDEsImp0aSI6IjQ3ODAwNjdiMDBlOWZiZTE5YzMzODZjZDdhMGQwN2UzYTA5ZjAyZWUifQ.oJav5ZxU5FWUmnsIBbOSgh68lHFalT2E6gsCqKet2pscTuqafYG8cAr7wxLpbkMp8MdzR_YrWCkrzVAiJiPi2yM7NpKQ_fXhwd6iejDmQF6nfWgGcbYX1VtEhwFd7E3TOzh2nRDOrF3KudCTzrAJOTVhXsfX6zzGstMwJOWMAOJXSHs4Y8XYXppvOuSnIXnYn4v0qnYKwmbSLNaMjC8hz0RhOILN5of3ijjfPmlPPruX_h-dIbYhcolVe6Xsp5imvIyFiKfJTuqlZCM7LS62f1jXRR2l5IEb-h32z1Y-m6XEIImfugsaPqfCwPESUeAPtOnqw2fO1DbeKoV9ZKTtdA
# https://cloud.google.com/firewall/docs/using-firewalls
# https://stackoverflow.com/questions/64490729/how-to-enable-allow-http-traffic-allow-http-traffic-on-google-compute-engine-w
# https://stackoverflow.com/questions/74817489/terraform-gcp-how-to-create-a-firewall-rule-to-deny-all-traffic-without-specify
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall.html
# https://cloud.google.com/firewall/docs/quickstarts/configure-nwfwpolicy-fqdn-egress 
# https://cloud.google.com/blog/topics/developers-practitioners/hierarchical-firewall-policy-automation-terraform

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# gcloud compute firewall-policies  list --folder=605471393111
# gcloud compute firewall-policies  describe base-fw-policy --folder=605471393111 --format 'value(selfLink)'

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Allow ingress rules (1000s)

# Firewall rule to allow ingress HTTPS traffic on vpc 
resource "google_compute_firewall" "vpc-allow-ingress-ipv4-https" {
  project       = var.common.project_id
  name          = "vpc-allow-ingress-ipv4-https"
  priority      = 1000
  source_ranges = module.usfs_info.usda_ipv4_allowed_ranges

  log_config {
    metadata = "EXCLUDE_ALL_METADATA"
  }

  network = google_compute_network.vpc.self_link
  direction     = "INGRESS"

  allow {
    protocol    = "tcp"         # transmission control protocol
    ports       = ["443"]       # 22 = ssh; 80 = http; 443 = https; 3389 = rdp:
  }
}

resource "google_compute_firewall" "vpc-allow-ingress-ipv6-https" {
  project       = var.common.project_id
  name          = "vpc-allow-ingress-ipv6-https"
  priority      = 1000
  source_ranges = module.usfs_info.usda_ipv6_allowed_ranges

  log_config {
    metadata = "EXCLUDE_ALL_METADATA"
  }

  network = google_compute_network.vpc.self_link
  direction     = "INGRESS"

  allow {
    protocol    = "tcp"         # transmission control protocol
    ports       = ["443"]       # 22 = ssh; 80 = http; 443 = https; 3389 = rdp:
  }
}

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Deny ingress rules (2000s)

# Firewall rule to deny ingress traffic on vpc ipv4
resource "google_compute_firewall" "vpc-deny-ingress-ipv4-all" {
  project       = var.common.project_id
  name          = "vpc-deny-ingress-ipv4-all"
  priority      = 2000

  source_ranges = [
    "0.0.0.0/0"
  ]

  log_config {
    metadata = "EXCLUDE_ALL_METADATA"
  }

  network = google_compute_network.vpc.self_link
  direction     = "INGRESS"

  deny {
    protocol    = "all"         # transmission control protocol
  }
}

# Firewall rule to deny ingress traffic on vpc ipv6
resource "google_compute_firewall" "vpc-deny-ingress-ipv6-all" {
  project       = var.common.project_id
  name          = "vpc-deny-ingress-ipv6-all"
  priority      = 2000

  source_ranges = [
    "::/0"
  ]

  log_config {
    metadata = "EXCLUDE_ALL_METADATA"
  }

  network = google_compute_network.vpc.self_link
  direction     = "INGRESS"

  deny {
    protocol    = "all"         # transmission control protocol
  }
}
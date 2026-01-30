output "static_ip" {
  description = "Static IP address for the load balancer"
  value       = google_compute_global_address.default.address
}

output "static_ip_name" {
  description = "Name of the static IP resource"
  value       = google_compute_global_address.default.name
}

output "ssl_certificate_id" {
  description = "ID of the SSL certificate"
  value       = google_compute_managed_ssl_certificate.default.id
}

output "ssl_certificate_status" {
  description = "Status of the SSL certificate"
  value       = google_compute_managed_ssl_certificate.default.managed[0].status
}

output "ssl_certificate_domains" {
  description = "Domains covered by the SSL certificate"
  value       = google_compute_managed_ssl_certificate.default.managed[0].domains
}

output "load_balancer_url" {
  description = "Full HTTPS URL of the load balancer"
  value       = "https://${google_compute_global_address.default.address}.nip.io"
}

output "url_map_id" {
  description = "ID of the URL map"
  value       = google_compute_url_map.default.id
}

output "https_proxy_id" {
  description = "ID of the HTTPS proxy"
  value       = google_compute_target_https_proxy.default.id
}

output "forwarding_rule_id" {
  description = "ID of the forwarding rule"
  value       = google_compute_global_forwarding_rule.default.id
}

output "hub_id" {
  description = "Resource ID of the NCC hub."
  value       = google_network_connectivity_hub.medsecure_hub.id
}

output "region_vpc_ids" {
  description = "Self-links of each region's Shared VPC."
  value       = { for k, v in google_compute_network.region_vpc : k => v.self_link }
}

output "region_subnet_ids" {
  description = "Self-links of each region's subnet."
  value       = { for k, v in google_compute_subnetwork.region_subnet : k => v.self_link }
}

output "cloud_armor_policy_id" {
  description = "ID of the Cloud Armor security policy (null if disabled)."
  value       = var.enable_cloud_armor ? google_compute_security_policy.medsecure_waf[0].id : null
}

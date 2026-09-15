output "api_cluster_endpoints" {
  description = "Endpoints of each region's GKE Autopilot cluster."
  value       = { for k, v in google_container_cluster.api_cluster : k => v.endpoint }
  sensitive   = true
}

output "cloud_run_service_urls" {
  description = "URLs of each deployed Cloud Run event-driven service."
  value       = { for k, v in google_cloud_run_v2_service.event_service : k => v.uri }
}

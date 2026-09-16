output "slo_names" {
  description = "SLO resource names per region -- reference for the drill/incident documentation."
  value       = { for k, v in google_monitoring_slo.api_availability : k => v.name }
}

output "dashboard_ids" {
  description = "Platform Health Summary dashboard IDs per region."
  value       = { for k, v in google_monitoring_dashboard.platform_health_summary : k => v.id }
}

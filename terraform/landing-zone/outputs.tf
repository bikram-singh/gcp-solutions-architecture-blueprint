output "environment_folder_ids" {
  description = "Folder IDs for prod / non-prod."
  value       = { for k, v in google_folder.environment : k => v.folder_id }
}

output "region_folder_ids" {
  description = "Folder IDs for each environment/region combination (e.g. prod-eu, prod-us)."
  value       = { for k, v in google_folder.region : k => v.folder_id }
}

output "shared_services_project_ids" {
  description = "Project IDs for cross-region shared services (network hub, logging)."
  value       = { for k, v in google_project.shared_services : k => v.project_id }
}

output "service_project_ids" {
  description = "Project IDs for every environment/region/service combination."
  value       = { for k, v in google_project.service : k => v.project_id }
}

output "perimeter_names" {
  description = "VPC-SC perimeter resource names, per region."
  value       = { for k, v in google_access_context_manager_service_perimeter.region_perimeter : k => v.name }
}

output "cmek_key_ids" {
  description = "Cloud KMS CMEK key IDs, per region -- reference these when applying CMEK to BigQuery/Cloud SQL/GCS resources in other modules."
  value       = { for k, v in google_kms_crypto_key.region_key : k => v.id }
}

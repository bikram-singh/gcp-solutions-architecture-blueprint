output "cloud_sql_primary_connection_names" {
  description = "Connection names of each region's primary Cloud SQL instance."
  value       = { for k, v in google_sql_database_instance.primary : k => v.connection_name }
}

output "telemetry_topic_ids" {
  description = "Pub/Sub topic IDs for wearable telemetry ingestion, per region."
  value       = { for k, v in google_pubsub_topic.telemetry : k => v.id }
}

output "bigquery_dataset_ids" {
  description = "BigQuery dataset IDs for telemetry analytics, per region."
  value       = { for k, v in google_bigquery_dataset.telemetry_analytics : k => v.id }
}


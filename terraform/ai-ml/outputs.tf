output "agent_service_urls" {
  description = "URLs of each region's deployed ADK clinician agent."
  value       = { for k, v in google_cloud_run_v2_service.clinician_agent : k => v.uri }
}

output "agent_service_account_emails" {
  description = "Service account emails for each region's agent -- for verifying IAM grants match the analyst-equivalent access principle from ADR-005."
  value       = { for k, v in google_service_account.agent_identity : k => v.email }
}

output "anomaly_endpoint_ids" {
  description = "Vertex AI endpoint IDs for the anomaly detection model, per region."
  value       = { for k, v in google_vertex_ai_endpoint.anomaly_detection : k => v.id }
}

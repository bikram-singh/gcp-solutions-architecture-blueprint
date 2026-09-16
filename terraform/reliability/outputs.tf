output "alert_policy_ids" {
  description = "Alert policy IDs per region -- confirm these exist before considering Step 1 of the runbook 'implemented'."
  value       = { for k, v in google_monitoring_alert_policy.primary_sql_down : k => v.id }
}

output "budget_id" {
  description = "The org-wide budget resource ID."
  value       = google_billing_budget.medsecure_org_budget.id
}

output "alert_thresholds" {
  description = "Configured alert thresholds, for confirming against the ADR-008 cost model."
  value       = var.alert_thresholds_percent
}

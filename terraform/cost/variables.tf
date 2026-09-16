variable "billing_account_id" {
  description = "Billing account to attach budget alerts to."
  type        = string
}

variable "org_id" {
  description = "GCP Organization ID -- budgets can be scoped org-wide."
  type        = string
}

variable "monthly_budget_amount_usd" {
  description = "Monthly budget threshold in USD. Illustrative starting point from the ADR-008 cost model -- revisit once real usage data exists."
  type        = number
  default     = 2000
}

variable "alert_thresholds_percent" {
  description = "Percentages of the budget at which alerts fire."
  type        = list(number)
  default     = [50, 80, 100, 120]
}

variable "notification_email" {
  description = "Email for budget alert notifications -- the monthly FinOps review cadence from ADR-008."
  type        = string
}

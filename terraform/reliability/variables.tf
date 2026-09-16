variable "regions" {
  description = "One primary Cloud SQL instance to monitor per region, plus the notification channel for its on-call."
  type = map(object({
    project_id        = string
    primary_instance_id = string
  }))
  default = {
    prod-eu = { project_id = "medsecure-eu-data-prod", primary_instance_id = "medsecure-prod-eu-sql" }
    prod-us = { project_id = "medsecure-us-data-prod", primary_instance_id = "medsecure-prod-us-sql" }
  }
}

variable "notification_email" {
  description = "Email address for the on-call notification channel that triggers Step 1 of the failover runbook."
  type        = string
}

variable "consecutive_failures_before_alert" {
  description = "Number of consecutive failed checks before paging -- matches the runbook's 'do not fail over on a single alert' threshold."
  type        = number
  default     = 3
}

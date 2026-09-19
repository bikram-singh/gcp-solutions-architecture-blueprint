terraform {
  required_version = ">= 1.7.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

# ---------------------------------------------------------------------------
# ADR-007: Reliability & Disaster Recovery
# Alerting that implements Step 1 ("Detect") of the failover runbook.
#
# REDESIGN NOTE: the original design used a google_monitoring_uptime_check_config
# against a cloudsql_database resource, which the Uptime Check API does not
# support (confirmed against the live API -- see known-deviations.md #5).
# This version queries Cloud SQL's own native "up" metric directly via an
# alert policy, with no uptime-check wrapper at all.
# ---------------------------------------------------------------------------

resource "google_monitoring_notification_channel" "oncall_email" {
  for_each     = var.regions
  project      = each.value.project_id
  display_name = "MedSecure ${each.key} on-call"
  type         = "email"

  labels = {
    email_address = var.notification_email
  }
}

resource "google_monitoring_alert_policy" "primary_sql_down" {
  for_each     = var.regions
  project      = each.value.project_id
  display_name = "medsecure-${each.key}-sql-primary-down"
  combiner     = "OR"

  conditions {
    display_name = "Primary Cloud SQL unreachable (3 consecutive checks)"
    condition_threshold {
      filter          = "resource.type=\"cloudsql_database\" AND resource.label.database_id=\"${each.value.project_id}:${each.value.primary_instance_id}\" AND metric.type=\"cloudsql.googleapis.com/database/up\""
      comparison      = "COMPARISON_LT"
      threshold_value = 1
      duration        = "${var.consecutive_failures_before_alert * 300}s"

      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_MIN"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.oncall_email[each.key].id]

  documentation {
    content   = "Primary Cloud SQL instance unreachable. This is Step 1 (Detect) of the failover runbook -- see docs/dr-drill/failover-runbook.md before taking any promotion action. Do not promote the replica on this alert alone; confirm per the runbook's trigger conditions first."
    mime_type = "text/markdown"
  }
}


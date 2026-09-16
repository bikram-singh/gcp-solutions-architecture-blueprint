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
# Monitoring and alerting that implements Step 1 ("Detect") of
# docs/dr-drill/failover-runbook.md. The replica itself is provisioned
# in terraform/data (ADR-004) -- this module only adds the detection
# and paging layer the runbook depends on.
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

# Uptime check against the primary Cloud SQL instance -- 3 consecutive
# failures (15 min at 5-min intervals) is the runbook's deliberate
# threshold before declaring an incident, avoiding false-positive failover.
resource "google_monitoring_uptime_check_config" "primary_sql_check" {
  for_each     = var.regions
  project      = each.value.project_id
  display_name = "medsecure-${each.key}-sql-primary-uptime"
  timeout      = "10s"
  period       = "300s" # 5 minutes, matching the runbook's threshold math

  monitored_resource {
    type = "cloudsql_database"
    labels = {
      project_id  = each.value.project_id
      database_id = "${each.value.project_id}:${each.value.primary_instance_id}"
    }
  }

  tcp_check {
    port = 5432
  }
}

resource "google_monitoring_alert_policy" "primary_sql_down" {
  for_each     = var.regions
  project      = each.value.project_id
  display_name = "medsecure-${each.key}-sql-primary-down"
  combiner     = "OR"

  conditions {
    display_name = "Primary Cloud SQL unreachable (${var.consecutive_failures_before_alert} consecutive checks)"
    condition_threshold {
      filter          = "resource.type=\"cloudsql_database\" AND metric.type=\"monitoring.googleapis.com/uptime_check/check_passed\" AND resource.label.database_id=\"${each.value.project_id}:${each.value.primary_instance_id}\""
      comparison      = "COMPARISON_LT"
      threshold_value = 1
      duration        = "${var.consecutive_failures_before_alert * 300}s"

      aggregations {
        alignment_period  = "300s"
        per_series_aligner = "ALIGN_FRACTION_TRUE"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.oncall_email[each.key].id]

  documentation {
    content   = "Primary Cloud SQL instance unreachable. This is Step 1 (Detect) of the failover runbook -- see docs/dr-drill/failover-runbook.md before taking any promotion action. Do not promote the replica on this alert alone; confirm per the runbook's trigger conditions first."
    mime_type = "text/markdown"
  }
}

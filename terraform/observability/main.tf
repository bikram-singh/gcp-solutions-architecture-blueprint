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
# ADR-010: Observability
# Formal SLO + burn-rate alerting for the API tier's 99.95% availability
# NFR, plus the golden-signals dashboards described in the ADR. This module
# does not duplicate Pillar 7 (DR alerting) or Pillar 8 (budget alerting) --
# it surfaces them into the Platform Health Summary dashboard instead.
# ---------------------------------------------------------------------------

resource "google_monitoring_service" "api_tier" {
  for_each     = var.api_project_ids
  project      = each.value
  service_id   = "medsecure-${each.key}-api-tier"
  display_name = "MedSecure API Tier (${each.key})"

  # NOTE: points at the webhook-ingestion Cloud Run service as a stand-in.
  # ADR-003's actual API tier runs on GKE Autopilot, which was not
  # successfully provisioned in this session (see known-deviations.md) --
  # this SLO demonstrates the mechanism against the nearest real, live
  # service rather than against infrastructure that does not yet exist.
  basic_service {
    service_type = "CLOUD_RUN"
    service_labels = {
      service_name = "webhook-ingestion"
      location     = "europe-west1"
    }
  }
}

resource "google_monitoring_slo" "api_availability" {
  for_each     = var.api_project_ids
  project      = each.value
  service      = google_monitoring_service.api_tier[each.key].service_id
  slo_id       = "medsecure-${each.key}-availability-slo"
  display_name = "API availability (99.95% NFR)"

  goal                = var.availability_slo_goal
  rolling_period_days = var.slo_rolling_period_days

  # Request-based SLO: good/total ratio of non-5xx responses.
  # This directly operationalizes the 99.95% NFR as a checkable target,
  # per ADR-010's core decision.
  request_based_sli {
    good_total_ratio {
      good_service_filter = "resource.type=\"cloud_run_revision\" AND metric.type=\"run.googleapis.com/request_count\" AND metric.label.response_code_class!=\"5xx\""
      total_service_filter = "resource.type=\"cloud_run_revision\" AND metric.type=\"run.googleapis.com/request_count\""
    }
  }
}

# --- Burn-rate alerts: fast (urgent) and slow (sustained) windows ----------
resource "google_monitoring_alert_policy" "slo_burn_fast" {
  for_each     = var.api_project_ids
  project      = each.value
  display_name = "medsecure-${each.key}-slo-fast-burn"
  combiner     = "OR"

  conditions {
    display_name = "Fast burn (1hr window, ${var.fast_burn_rate_threshold}x threshold)"
    condition_threshold {
      filter          = "select_slo_burn_rate(\"${google_monitoring_slo.api_availability[each.key].name}\", \"3600s\")"
      comparison      = "COMPARISON_GT"
      threshold_value = var.fast_burn_rate_threshold
      duration        = "0s"
    }
  }

  documentation {
    content   = "Error budget burning fast -- this is an urgent, current incident, not a sustained trend. Check the API Tier Golden Signals dashboard first."
    mime_type = "text/markdown"
  }
}

resource "google_monitoring_alert_policy" "slo_burn_slow" {
  for_each     = var.api_project_ids
  project      = each.value
  display_name = "medsecure-${each.key}-slo-slow-burn"
  combiner     = "OR"

  conditions {
    display_name = "Slow burn (6hr window, ${var.slow_burn_rate_threshold}x threshold)"
    condition_threshold {
      filter          = "select_slo_burn_rate(\"${google_monitoring_slo.api_availability[each.key].name}\", \"21600s\")"
      comparison      = "COMPARISON_GT"
      threshold_value = var.slow_burn_rate_threshold
      duration        = "0s"
    }
  }

  documentation {
    content   = "Error budget burning steadily over a 6hr window -- a sustained degradation worth investigating, less urgent than the fast-burn alert."
    mime_type = "text/markdown"
  }
}

# --- Platform Health Summary dashboard --------------------------------------
resource "google_monitoring_dashboard" "platform_health_summary" {
  for_each       = var.api_project_ids
  project        = each.value
  dashboard_json = jsonencode({
    displayName = "MedSecure Platform Health Summary (${each.key})"
    mosaicLayout = {
      columns = 12
      tiles = [
        {
          xPos   = 0
          yPos   = 0
          width  = 6
          height = 4
          widget = {
            title = "API Availability SLO — error budget remaining"
            scorecard = {
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "select_slo_health(\"${google_monitoring_slo.api_availability[each.key].name}\")"
                }
              }
            }
          }
        },
        {
          xPos   = 0
          yPos   = 4
          width  = 6
          height = 4
          widget = {
            title = "Note"
            text = {
              content = "This summary surfaces Pillar 7's DR trigger alert and Pillar 8's budget alert by reference -- see their respective dashboards for detail. This dashboard is the single-glance platform-health view described in ADR-010, not a replacement for the per-domain dashboards."
              format  = "MARKDOWN"
            }
          }
        }
      ]
    }
  })
}






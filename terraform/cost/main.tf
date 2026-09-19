terraform {
  required_version = ">= 1.7.0"

  cloud {
    organization = "gcpcloudhub"
    workspaces {
      name = "medsecure-cost"
    }
  }
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

# ---------------------------------------------------------------------------
# ADR-008: Cost Optimization / FinOps
# Budget alerts implementing the monthly FinOps review cadence. This module
# does NOT implement Committed Use Discounts (those are purchased directly
# via the Billing console/API against forecast commitments, not something
# to provision blindly via Terraform without a real usage baseline first --
# see the README for why that's deliberately out of scope here).
# ---------------------------------------------------------------------------

resource "google_monitoring_notification_channel" "finops_email" {
  project      = "medsecure-logging" # lives in shared-services, same as the org-wide logging/monitoring resources
  display_name = "MedSecure FinOps review"
  type         = "email"

  labels = {
    email_address = var.notification_email
  }
}

resource "google_billing_budget" "medsecure_org_budget" {
  billing_account = var.billing_account_id
  display_name    = "medsecure-org-monthly-budget"

  budget_filter {
    credit_types_treatment = "INCLUDE_ALL_CREDITS"
    calendar_period         = "MONTH"
  }

  amount {
    specified_amount {
      currency_code = "INR"
      units         = tostring(var.monthly_budget_amount_usd)
    }
  }

  dynamic "threshold_rules" {
    for_each = var.alert_thresholds_percent
    content {
      threshold_percent = threshold_rules.value / 100
    }
  }

  all_updates_rule {
    monitoring_notification_channels = [google_monitoring_notification_channel.finops_email.id]
  }
}

provider "google" {
  project                = "medsecure-logging"
  user_project_override  = true
  billing_project         = "medsecure-logging"
}






terraform {
  required_version = ">= 1.7.0"

  cloud {
    organization = "gcpcloudhub"
    workspaces {
      name = "medsecure-data"
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
# ADR-004: Data & Analytics
# Cloud SQL (OLTP) + Pub/Sub -> Dataflow -> BigQuery (streaming analytics),
# governed by Dataplex. Each per region, respecting residency from ADR-001/002.
#
# KNOWN TEMPORARY DEVIATION (see docs/known-deviations.md):
# Cloud SQL's ip_configuration below currently uses a public IP with a
# locked-down authorized network, NOT the private-only design ADR-002
# specifies. This exists only because the network module needs its own
# billed shared-services project, unavailable during this session's
# billing-quota-constrained minimal proof. Revert once network is live.
# ---------------------------------------------------------------------------

# --- Cloud SQL: transactional portal/account state --------------------------
resource "google_sql_database_instance" "primary" {
  for_each         = var.regions
  project          = each.value.data_project_id
  name             = "medsecure-${each.key}-sql"
  region           = each.value.region
  database_version = "POSTGRES_15"

  settings {
    tier              = var.cloud_sql_tier
    availability_type = "REGIONAL" # regional HA, directly serves the availability NFR

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = true # required to meet the <=15 min RPO NFR
      transaction_log_retention_days = 7
    }

    ip_configuration {
      # Private-only, per ADR-002. The temporary public-IP deviation
      # (known-deviations.md item 1/2) is resolved now that Private
      # Service Access exists in the network module.
      ipv4_enabled    = false
      private_network = var.vpc_self_link
    }
  }

  deletion_protection = false
}

# --- Pub/Sub: wearable telemetry ingestion -----------------------------------
resource "google_pubsub_topic" "telemetry" {
  for_each = var.regions
  project  = each.value.data_project_id
  name     = "medsecure-${each.key}-telemetry"
}

resource "google_pubsub_subscription" "telemetry_dataflow" {
  for_each = var.regions
  project  = each.value.data_project_id
  name     = "medsecure-${each.key}-telemetry-dataflow-sub"
  topic    = google_pubsub_topic.telemetry[each.key].id

  # NOTE: the Dataflow job itself is defined in the standalone streaming
  # telemetry pipeline project and reused here, not redefined -- this
  # module only provisions the topic/subscription MedSecure-side.
}

# --- BigQuery: analytics warehouse -------------------------------------------
resource "google_bigquery_dataset" "telemetry_analytics" {
  for_each    = var.regions
  project     = each.value.data_project_id
  dataset_id  = "medsecure_${replace(each.key, "-", "_")}_telemetry"
  location    = each.value.region
}

# --- Dataplex: governance + PII policy tags ----------------------------------
resource "google_dataplex_lake" "medsecure" {
  for_each = var.regions
  project  = each.value.data_project_id
  name     = "medsecure-${each.key}-lake"
  location = each.value.region
}




provider "google" {
  project                = "medsecure-eu-data-prod"
  user_project_override  = true
  billing_project         = "medsecure-eu-data-prod"
}


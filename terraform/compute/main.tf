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
# ADR-003: Compute & Modernization
# GKE Autopilot for the stateful API/backend tier; Cloud Run for
# event-driven services (webhook ingestion, notification dispatch).
# ---------------------------------------------------------------------------

# --- GKE Autopilot clusters, one per region ---------------------------------
resource "google_container_cluster" "api_cluster" {
  for_each = var.api_clusters
  project  = each.value.project_id
  name     = "medsecure-${each.key}-api"
  location = each.value.region

  enable_autopilot = true

  network    = each.value.network
  subnetwork = each.value.subnetwork

  # Workload Identity is on by default in Autopilot, but stated explicitly
  # here since it's the load-bearing control for the least-privilege NFR.
  workload_identity_config {
    workload_pool = "${each.value.project_id}.svc.id.goog"
  }

  release_channel {
    channel = "REGULAR"
  }

  deletion_protection = true
}

# --- Cloud Run services, event-driven tier ----------------------------------
resource "google_cloud_run_v2_service" "event_service" {
  for_each = var.cloud_run_services
  project  = each.value.project_id
  name     = split("-", each.key)[length(split("-", each.key)) - 2] == "webhook" ? "webhook-ingestion" : "notification-dispatch"
  location = each.value.region

  template {
    scaling {
      min_instance_count = var.cloud_run_min_instances
      max_instance_count = var.cloud_run_max_instances
    }

    containers {
      image = each.value.image
    }

    # Workload Identity Federation — no service account keys.
    service_account = google_service_account.cloud_run_identity[each.key].email
  }
}

resource "google_service_account" "cloud_run_identity" {
  for_each     = var.cloud_run_services
  project      = each.value.project_id
  # GCP account_id has a 30-char limit -- keep the prefix short and truncate the key.
  account_id   = "ms-${substr(each.key, 0, 24)}-sa"
  display_name = "Workload identity for ${each.key} (no long-lived keys)"
}

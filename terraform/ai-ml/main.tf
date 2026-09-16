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
# ADR-005: AI/ML Layer
# Vertex AI Model Garden anomaly detection (per region) + the existing ADK
# agent, deployed per region and grounded on that region's BigQuery dataset
# only -- never across the eu/us residency boundary.
# ---------------------------------------------------------------------------

# --- Workload identity for the agent: SAME access as a human clinical
#     analyst would have -- no elevated agent-specific permissions.
#     This is the core containment decision from ADR-005. ---------------------
resource "google_service_account" "agent_identity" {
  for_each     = var.regions
  project      = each.value.ml_project_id
  account_id   = "medsecure-${each.key}-agent"
  display_name = "ADK agent identity (${each.key}) -- analyst-equivalent access only"
}

# Grant the agent's identity the same BigQuery role a human analyst gets --
# deliberately NOT bigquery.admin or anything broader.
resource "google_project_iam_member" "agent_bq_access" {
  for_each = var.regions
  project  = each.value.ml_project_id
  role     = "roles/bigquery.dataViewer"
  member   = "serviceAccount:${google_service_account.agent_identity[each.key].email}"
}

resource "google_project_iam_member" "agent_bq_job_user" {
  for_each = var.regions
  project  = each.value.ml_project_id
  role     = "roles/bigquery.jobUser"
  member   = "serviceAccount:${google_service_account.agent_identity[each.key].email}"
}

# --- ADK agent, deployed as a Cloud Run service per region ------------------
resource "google_cloud_run_v2_service" "clinician_agent" {
  for_each = var.regions
  project  = each.value.ml_project_id
  name     = "medsecure-${each.key}-clinician-agent"
  location = each.value.region

  template {
    scaling {
      min_instance_count = var.agent_min_instances
      max_instance_count = var.agent_max_instances
    }

    containers {
      image = var.agent_container_image

      env {
        name  = "BIGQUERY_PROJECT"
        value = each.value.ml_project_id
      }
      env {
        name  = "AGENT_REGION"
        value = each.key
      }
      # NOTE: the agent's BigQuery grounding queries are scoped at the
      # application layer to this project's dataset only -- combined with
      # the IAM grants above, this is defense-in-depth: even a scoping bug
      # in the app layer cannot escalate past analyst-equivalent access.
    }

    service_account = google_service_account.agent_identity[each.key].email
  }
}

# --- Vertex AI endpoint for the anomaly detection model, per region ---------
resource "google_vertex_ai_endpoint" "anomaly_detection" {
  for_each     = var.regions
  project      = each.value.ml_project_id
  name         = "medsecure-${each.key}-anomaly-endpoint"
  display_name = "MedSecure anomaly detection (${each.key})"
  location     = each.value.region

  # NOTE: the Model Garden model itself is deployed to this endpoint via
  # a separate, non-Terraform-managed step (gcloud ai models deploy), since
  # Model Garden deployment isn't fully declarative in the provider at time
  # of writing. This endpoint resource provisions the serving infrastructure
  # the deployment step targets.
}

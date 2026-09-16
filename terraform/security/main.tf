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
# ADR-006: Security & Compliance
# Per-region VPC-SC perimeters (extending the existing VPC-SC lab design) +
# CMEK per region + Secret Manager + Security Command Center Premium.
# ---------------------------------------------------------------------------

# --- One org-level access policy (required once per org for VPC-SC) --------
resource "google_access_context_manager_access_policy" "medsecure" {
  parent = "organizations/${var.org_id}"
  title  = "medsecure-access-policy"
}

# --- One perimeter per region -- deliberately NOT one global perimeter,
#     per ADR-006's core decision. No implicit bridge between them. --------
resource "google_access_context_manager_service_perimeter" "region_perimeter" {
  for_each       = var.perimeters
  parent         = "accessPolicies/${google_access_context_manager_access_policy.medsecure.name}"
  name           = "accessPolicies/${google_access_context_manager_access_policy.medsecure.name}/servicePerimeters/medsecure_${replace(each.key, "-", "_")}"
  title          = "medsecure-${each.key}-perimeter"
  perimeter_type = "PERIMETER_TYPE_REGULAR"

  status {
    resources           = [for num in each.value.project_numbers : "projects/${num}"]
    restricted_services  = var.restricted_services
  }
}

# --- CMEK: one key ring + key per region, per data-holding project ---------
# --- CMEK: one key ring + key per region, per data-holding project ---------
resource "google_kms_key_ring" "region_keyring" {
  for_each = var.kms_locations
  project  = var.cmek_project_ids[each.key][0] # key ring lives in that region's first data project
  name     = "medsecure-${each.key}-keyring"
  location = each.value
}

resource "google_kms_crypto_key" "region_key" {
  for_each = var.kms_locations
  name     = "medsecure-${each.key}-cmek"
  key_ring = google_kms_key_ring.region_keyring[each.key].id

  rotation_period = "7776000s" # 90 days

  lifecycle {
    prevent_destroy = true # a destroyed CMEK key permanently orphans encrypted data -- never allow accidental destroy
  }
}

# --- Security Command Center Premium: org-level, covers every project ------
resource "google_scc_v2_organization_scc_big_query_exports" "medsecure_scc_export" {
  organization = var.org_id
  location     = "global"
  big_query_export_id = "medsecure-scc-findings"
  description  = "SCC Premium findings exported for centralized review, feeding the same logging project as Cloud Audit Logs."
  dataset      = "projects/medsecure-logging/datasets/scc_findings" # dataset created in the data module's logging project
}


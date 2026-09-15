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
# ADR-001: Landing Zone & Resource Hierarchy
# Org -> Folder (environment) -> Folder (region) -> Project (service)
# Shared services (network hub, logging) sit in their own top-level folder,
# outside the eu/us split, and never hold customer data.
# ---------------------------------------------------------------------------

# --- Environment folders (prod / non-prod) ---------------------------------
resource "google_folder" "environment" {
  for_each     = toset(var.environments)
  display_name = each.key
  parent       = "organizations/${var.org_id}"
}

# --- Region folders, nested under each environment folder ------------------
resource "google_folder" "region" {
  for_each = {
    for pair in setproduct(var.environments, keys(var.regions)) :
    "${pair[0]}-${pair[1]}" => {
      environment = pair[0]
      region      = pair[1]
    }
  }
  display_name = each.value.region
  parent       = google_folder.environment[each.value.environment].id
}

# --- Data residency enforcement: org policy per region folder --------------
# This is the load-bearing control from ADR-001 — residency is enforced
# structurally at the folder level, not left to labeling convention.
resource "google_org_policy_policy" "resource_location" {
  for_each = google_folder.region
  name     = "${each.value.name}/policies/gcp.resourceLocations"
  parent   = each.value.name

  spec {
    rules {
      values {
        allowed_values = [
          "in:${var.regions[split("-", each.key)[length(split("-", each.key)) - 1]].resource_location_group}"
        ]
      }
    }
  }
}

# --- Shared services folder (network hub, centralized logging) -------------
resource "google_folder" "shared_services" {
  display_name = "shared-services"
  parent       = "organizations/${var.org_id}"
}

resource "google_project" "shared_services" {
  for_each        = toset(var.shared_services_projects)
  name            = "${var.project_prefix}-${each.key}"
  project_id      = "${var.project_prefix}-${each.key}"
  folder_id       = google_folder.shared_services.folder_id
  billing_account = var.billing_account
  labels = {
    scope = "shared-services"
  }
}

# --- Service projects, one set per environment/region ----------------------
locals {
  service_projects = {
    for combo in setproduct(var.environments, keys(var.regions), var.services_per_region) :
    "${combo[0]}-${combo[1]}-${combo[2]}" => {
      environment = combo[0]
      region      = combo[1]
      service     = combo[2]
    }
  }
}

resource "google_project" "service" {
  for_each        = local.service_projects
  name            = "${var.project_prefix}-${each.value.region}-${each.value.service}"
  project_id      = "${var.project_prefix}-${each.value.region}-${each.value.service}-${each.value.environment}"
  folder_id       = google_folder.region["${each.value.environment}-${each.value.region}"].folder_id
  billing_account = var.billing_account
  labels = {
    environment = each.value.environment
    region      = each.value.region
    service     = each.value.service
  }
}

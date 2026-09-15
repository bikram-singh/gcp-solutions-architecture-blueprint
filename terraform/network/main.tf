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
# ADR-002: Network Architecture
# NCC hub in shared-services + one Shared VPC spoke per environment/region,
# preserving the eu/us residency boundary established in ADR-001.
# ---------------------------------------------------------------------------

# --- NCC Hub -----------------------------------------------------------------
resource "google_network_connectivity_hub" "medsecure_hub" {
  project     = var.hub_project_id
  name        = "medsecure-hub"
  description = "Central connectivity hub for all region Shared VPC spokes. Routing/metadata only -- no workload traffic terminates here."
}

# --- Shared VPCs, one per environment/region spoke ---------------------------
resource "google_compute_network" "region_vpc" {
  for_each                = var.region_networks
  project                  = each.value.host_project_id
  name                     = "medsecure-${each.key}-vpc"
  auto_create_subnetworks = false
  routing_mode             = "REGIONAL"
}

resource "google_compute_subnetwork" "region_subnet" {
  for_each      = var.region_networks
  project       = each.value.host_project_id
  name          = "medsecure-${each.key}-subnet"
  ip_cidr_range = each.value.subnet_cidr
  region        = each.value.region
  network       = google_compute_network.region_vpc[each.key].id

  private_ip_google_access = true # required for Private Google Access to managed services, no public IPs on backend tiers
}

# --- Enable each region VPC as a Shared VPC host -----------------------------
resource "google_compute_shared_vpc_host_project" "host" {
  for_each = var.region_networks
  project  = each.value.host_project_id
  depends_on = [google_compute_network.region_vpc]
}

# --- Attach service projects (from landing-zone module) as service projects --
locals {
  service_project_attachments = merge([
    for spoke, projects in var.service_projects_by_spoke : {
      for p in projects : "${spoke}-${p}" => {
        host_project_id    = var.region_networks[spoke].host_project_id
        service_project_id = p
      }
    }
  ]...)
}

resource "google_compute_shared_vpc_service_project" "attach" {
  for_each        = local.service_project_attachments
  host_project    = each.value.host_project_id
  service_project = each.value.service_project_id
  depends_on      = [google_compute_shared_vpc_host_project.host]
}

# --- Attach each Shared VPC to the NCC hub as a spoke -------------------------
resource "google_network_connectivity_spoke" "region_spoke" {
  for_each  = var.region_networks
  project   = each.value.host_project_id
  name      = "medsecure-${each.key}-spoke"
  location  = "global"
  hub       = google_network_connectivity_hub.medsecure_hub.id

  linked_vpc_network {
    uri = google_compute_network.region_vpc[each.key].id
  }
}

# --- Cloud Armor security policy: WAF + adaptive protection + rate limiting --
resource "google_compute_security_policy" "medsecure_waf" {
  count       = var.enable_cloud_armor ? 1 : 0
  project     = var.hub_project_id
  name        = "medsecure-edge-waf"
  description = "Edge WAF for the MedSecure API tier -- absorbs seasonal traffic spikes without manual intervention (NFR)."

  adaptive_protection_config {
    layer_7_ddos_defense_config {
      enable = true
    }
  }

  # Default allow, rate-limited per client IP
  rule {
    action   = "rate_based_ban"
    priority = 1000
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    rate_limit_options {
      conform_action = "allow"
      exceed_action  = "deny(429)"
      enforce_on_key = "IP"
      rate_limit_threshold {
        count        = var.rate_limit_threshold_per_minute
        interval_sec = 60
      }
      ban_duration_sec = 300
    }
    description = "Rate limit per client IP; sized to absorb legitimate seasonal spikes, block abuse."
  }

  rule {
    action   = "deny(403)"
    priority = 2000
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('sqli-stable') || evaluatePreconfiguredExpr('xss-stable')"
      }
    }
    description = "Managed WAF rules: SQLi and XSS protection."
  }

  rule {
    action   = "allow"
    priority = 2147483647
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Default allow rule."
  }
}

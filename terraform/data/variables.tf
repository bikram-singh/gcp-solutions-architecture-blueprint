variable "regions" {
  description = "One Cloud SQL instance + BigQuery dataset + Pub/Sub topic per region, respecting the residency boundary from ADR-001/002."
  type = map(object({
    data_project_id = string
    region            = string
  }))
  default = {
    prod-eu = { data_project_id = "medsecure-eu-data-prod", region = "europe-west1" }
    prod-us = { data_project_id = "medsecure-us-data-prod", region = "us-central1" }
  }
}

variable "cross_region_replica_map" {
  description = "Maps each primary Cloud SQL region to its DR replica region (same-country/compliant pairing, not cross-residency)."
  type        = map(string)
  default = {
    prod-eu = "europe-west4" # EU-to-EU DR pairing, never eu-to-us
    prod-us = "us-east1"
  }
}

variable "cloud_sql_tier" {
  description = "Cloud SQL machine tier for the primary instance."
  type        = string
  default     = "db-custom-4-16384"
}

variable "authorized_ip_ranges" {
  description = "TEMPORARY (see docs/known-deviations.md): authorized IPs for Cloud SQL public-IP access, pending the network module."
  type        = map(string)
  default     = {}
}

variable "vpc_self_link" {
  description = "Self-link of the region VPC (from the network module output), now that Private Service Access exists -- see known-deviations.md item 1/2 for why this replaces the temporary public-IP config."
  type        = string
}

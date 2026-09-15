variable "org_id" {
  description = "GCP Organization ID that owns the MedSecure landing zone."
  type        = string
}

variable "billing_account" {
  description = "Billing account ID to attach to every project created by this module."
  type        = string
}

variable "environments" {
  description = "Top-level environment folders (e.g. prod, non-prod)."
  type        = list(string)
  default     = ["prod", "non-prod"]
}

variable "regions" {
  description = "Region folders nested under each environment folder, mapped to the resource-location group used by the org policy constraint."
  type = map(object({
    resource_location_group = string # e.g. "eu-locations" or "us-locations"
  }))
  default = {
    eu = { resource_location_group = "eu-locations" }
    us = { resource_location_group = "us-locations" }
  }
}

variable "services_per_region" {
  description = "Service project suffixes created under every environment/region folder (e.g. api, data, ml)."
  type        = list(string)
  default     = ["api", "data", "ml"]
}

variable "project_prefix" {
  description = "Prefix used for all generated project IDs."
  type        = string
  default     = "medsecure"
}

variable "shared_services_projects" {
  description = "Projects created once, outside the eu/us split, for cross-region infra (network hub, centralized logging)."
  type        = list(string)
  default     = ["network-hub", "logging"]
}

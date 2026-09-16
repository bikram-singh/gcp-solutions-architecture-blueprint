variable "org_id" {
  description = "GCP Organization ID -- VPC-SC access policies are org-level resources."
  type        = string
}

variable "perimeters" {
  description = "One VPC-SC perimeter per region, listing the projects it wraps."
  type = map(object({
    project_numbers = list(string) # project NUMBERS, not IDs -- VPC-SC access policy API requires numbers
  }))
  default = {
    prod-eu = { project_numbers = [] } # fill from landing-zone module outputs (project numbers, not IDs)
    prod-us = { project_numbers = [] }
  }
}

variable "restricted_services" {
  description = "Google Cloud services restricted within each perimeter."
  type        = list(string)
  default = [
    "bigquery.googleapis.com",
    "sqladmin.googleapis.com",
    "storage.googleapis.com",
    "aiplatform.googleapis.com",
  ]
}

variable "kms_locations" {
  description = "Cloud KMS key ring location per region -- keys never leave their region, same residency discipline as every other pillar."
  type        = map(string)
  default = {
    prod-eu = "europe-west1"
    prod-us = "us-central1"
  }
}

variable "cmek_project_ids" {
  description = "Data-holding projects per region that get CMEK applied (from landing-zone module outputs)."
  type        = map(list(string))
  default = {
    prod-eu = ["medsecure-eu-data-prod", "medsecure-eu-ml-prod"]
    prod-us = ["medsecure-us-data-prod", "medsecure-us-ml-prod"]
  }
}

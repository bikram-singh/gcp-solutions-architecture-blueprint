variable "hub_project_id" {
  description = "Project ID of the shared-services project hosting the NCC hub (e.g. medsecure-network-hub, from the landing-zone module output)."
  type        = string
}

variable "region_networks" {
  description = "One Shared VPC per environment/region spoke, with its host project and subnet CIDR ranges."
  type = map(object({
    host_project_id = string
    region           = string # GCP region, e.g. us-central1, europe-west1
    subnet_cidr      = string
  }))
  default = {
    prod-eu = {
      host_project_id = "medsecure-eu-network-prod"
      region           = "europe-west1"
      subnet_cidr      = "10.10.0.0/20"
    }
    prod-us = {
      host_project_id = "medsecure-us-network-prod"
      region           = "us-central1"
      subnet_cidr      = "10.20.0.0/20"
    }
  }
}

variable "service_projects_by_spoke" {
  description = "Which service projects (from the landing-zone module) attach to each Shared VPC spoke as service projects."
  type        = map(list(string))
  default = {
    prod-eu = ["medsecure-eu-api-prod", "medsecure-eu-data-prod", "medsecure-eu-ml-prod"]
    prod-us = ["medsecure-us-api-prod", "medsecure-us-data-prod", "medsecure-us-ml-prod"]
  }
}

variable "enable_cloud_armor" {
  description = "Attach the Cloud Armor security policy to the load balancer backend."
  type        = bool
  default     = true
}

variable "rate_limit_threshold_per_minute" {
  description = "Requests per minute per client IP before Cloud Armor rate limiting engages — sized to absorb legitimate seasonal spikes while still blocking abuse."
  type        = number
  default     = 3000
}

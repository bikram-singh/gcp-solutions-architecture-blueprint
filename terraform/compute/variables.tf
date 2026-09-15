variable "api_clusters" {
  description = "One GKE Autopilot cluster per region, deployed into the Shared VPC/subnet from the network module."
  type = map(object({
    project_id = string
    region      = string
    network      = string # self_link from the network module's region_vpc_ids output
    subnetwork   = string # self_link from the network module's region_subnet_ids output
  }))
  default = {
    prod-eu = {
      project_id = "medsecure-eu-api-prod"
      region      = "europe-west1"
      network      = "" # fill from network module output
      subnetwork   = "" # fill from network module output
    }
    prod-us = {
      project_id = "medsecure-us-api-prod"
      region      = "us-central1"
      network      = ""
      subnetwork   = ""
    }
  }
}

variable "cloud_run_services" {
  description = "Event-driven Cloud Run services, one set per region."
  type = map(object({
    project_id = string
    region      = string
    image        = string # container image URI
  }))
  default = {
    prod-eu-webhook-ingestion = {
      project_id = "medsecure-eu-api-prod"
      region      = "europe-west1"
      image        = "gcr.io/medsecure-eu-api-prod/webhook-ingestion:latest"
    }
    prod-eu-notification-dispatch = {
      project_id = "medsecure-eu-api-prod"
      region      = "europe-west1"
      image        = "gcr.io/medsecure-eu-api-prod/notification-dispatch:latest"
    }
    prod-us-webhook-ingestion = {
      project_id = "medsecure-us-api-prod"
      region      = "us-central1"
      image        = "gcr.io/medsecure-us-api-prod/webhook-ingestion:latest"
    }
    prod-us-notification-dispatch = {
      project_id = "medsecure-us-api-prod"
      region      = "us-central1"
      image        = "gcr.io/medsecure-us-api-prod/notification-dispatch:latest"
    }
  }
}

variable "cloud_run_min_instances" {
  description = "Minimum instances per Cloud Run service. 0 = true scale-to-zero for the sub-linear cost NFR."
  type        = number
  default     = 0
}

variable "cloud_run_max_instances" {
  description = "Maximum instances per Cloud Run service, sized to absorb seasonal spikes."
  type        = number
  default     = 50
}

variable "regions" {
  description = "One anomaly-detection model deployment + one ADK agent instance per region, respecting residency from ADR-001/002."
  type = map(object({
    ml_project_id = string
    region         = string
  }))
  default = {
    prod-eu = { ml_project_id = "medsecure-eu-ml-prod", region = "europe-west1" }
    prod-us = { ml_project_id = "medsecure-us-ml-prod", region = "us-central1" }
  }
}

variable "agent_container_image" {
  description = "Container image URI for the ADK agent (built from the existing terraform-adk-agent project, extended with BigQuery grounding)."
  type        = string
  default     = "gcr.io/PROJECT_ID/medsecure-clinician-agent:latest"
}

variable "anomaly_model_id" {
  description = "Vertex AI Model Garden model resource ID used for anomaly detection (pre-trained, not custom-trained per ADR-005)."
  type        = string
  default     = "publishers/google/models/anomaly-detection-timeseries"
}

variable "agent_min_instances" {
  description = "Minimum Cloud Run instances for the ADK agent. 0 = scale-to-zero outside clinic hours."
  type        = number
  default     = 0
}

variable "agent_max_instances" {
  description = "Maximum Cloud Run instances for the ADK agent, sized to absorb seasonal query spikes."
  type        = number
  default     = 20
}

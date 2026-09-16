variable "api_project_ids" {
  description = "API-tier project IDs per region, whose SLO this module defines."
  type        = map(string)
  default = {
    prod-eu = "medsecure-eu-api-prod"
    prod-us = "medsecure-us-api-prod"
  }
}

variable "availability_slo_goal" {
  description = "Availability SLO target, matching the 99.95% NFR."
  type        = number
  default     = 0.9995
}

variable "slo_rolling_period_days" {
  description = "Rolling window for the SLO compliance calculation."
  type        = number
  default     = 30
}

variable "fast_burn_rate_threshold" {
  description = "Burn-rate multiplier that triggers the fast (1hr window) alert -- a genuinely urgent, budget-exhausting event."
  type        = number
  default     = 14.4 # standard Google SRE-book fast-burn threshold for a 1hr window against a 30-day SLO
}

variable "slow_burn_rate_threshold" {
  description = "Burn-rate multiplier that triggers the slow (6hr window) alert -- a sustained, less urgent but still real degradation."
  type        = number
  default     = 6
}

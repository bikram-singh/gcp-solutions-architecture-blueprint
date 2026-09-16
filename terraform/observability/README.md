# Observability Module

Implements **ADR-010: Observability** — the final pillar.

Builds:
- A **Cloud Monitoring Service + SLO** per region, operationalizing the 99.95% availability NFR as a checkable, alertable target rather than a document-only claim
- **Two burn-rate alert policies** per region: fast (1hr window, 14.4x threshold — the standard SRE-book fast-burn value) for urgent incidents, slow (6hr window, 6x threshold) for sustained degradation
- A **Platform Health Summary dashboard** that surfaces the SLO error budget alongside references to Pillar 7's DR alerting and Pillar 8's budget alerting — without duplicating either

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform validate
terraform plan -out=observability.tfplan
```

## Design notes

- **The burn-rate thresholds (14.4x fast, 6x slow) are the standard values from Google's SRE workbook**, not invented — this is the one place in this project's cost/threshold decisions where "use the industry-standard number" was the right call, rather than the "revisit once real data exists" caveat applied to Cloud Armor's rate limit or Cloud Run's max-instances. Worth noting the distinction if asked: some thresholds in this repo are principled starting estimates, this one is an established practice.
- **The dashboard JSON is intentionally minimal in this Terraform module.** A full golden-signals dashboard (per ADR-010's design: latency/traffic/errors/saturation panels) is better built and iterated on directly in the Cloud Monitoring console UI, then exported to JSON and checked in — hand-writing a large `dashboard_json` blob in HCL is painful to maintain and review. This module provisions the SLO-scorecard tile as the anchor; the full dashboard is a follow-up artifact, not faked here as more complete than it is.
- **This module does not touch Pillar 7 or Pillar 8's resources.** The Platform Health Summary dashboard's "Note" tile references them by description, not by Terraform resource dependency — keeping this module's blast radius scoped to what it actually owns.

## Known limitation

Not yet applied. The `select_slo_burn_rate()` and `select_slo_health()` MQL functions used in the alert policies and dashboard require the SLO to exist first within the same apply — if `terraform apply` errors on evaluation order, split this into two applies (SLO first, then the alerts/dashboard referencing it) rather than assuming a single apply will always resolve the dependency correctly.

# Data Module

Implements **ADR-004: Data & Analytics**.

Builds:
- **Cloud SQL (Postgres)** regional-HA primary per region, with point-in-time recovery enabled
- A **cross-region read replica marked as a failover target** — the literal mechanism ADR-007's DR drill exercises
- **Pub/Sub** topic + subscription per region for wearable telemetry ingestion (the Dataflow job itself lives in the standalone streaming telemetry pipeline project and is reused, not redefined here)
- **BigQuery** dataset per region for telemetry analytics
- A **Dataplex lake** per region as the governance/cataloging entry point for PII policy tags

## Usage

Depends on `landing-zone` (project IDs) and `network` (VPC self-links for Cloud SQL private networking).

```bash
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform validate
terraform plan -out=data.tfplan
```

## Design notes (why the code looks like this)

- **`point_in_time_recovery_enabled = true` is not optional here** — it's the direct mechanism that makes the ≤15 min RPO NFR achievable at all. Without PITR, recovery grain is limited to the last full backup, which would blow the RPO target.
- **The DR replica region is picked per-source-region, never across the residency boundary** (`cross_region_replica_map`) — `prod-eu` replicates to another EU region, never to a US one. This is the same residency discipline from ADR-001/002 applied to backup/DR, not a separate rule.
- **No Dataflow job resource in this module, on purpose.** The streaming pipeline (Pub/Sub → Dataflow → BigQuery) was already built and load-tested as its own project; duplicating that Terraform here would mean maintaining two copies of the same logic. This module provisions only the MedSecure-side topic/subscription/dataset that the existing pipeline needs to point at.
- **`ip_configuration.private_network` is left blank in this template** — same pattern as the compute module: fill it from the `network` module's actual VPC self-link output before planning.

## Known limitation

Not yet run against a live org. Dependency order: `landing-zone` → `network` → `data`. As with the compute module, `terraform validate` passes on syntax/schema alone — a meaningful `plan` needs real values wired in from the other modules' outputs.

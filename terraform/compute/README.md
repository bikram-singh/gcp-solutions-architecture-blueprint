# Compute Module

Implements **ADR-003: Compute & Modernization**.

Builds:
- One **GKE Autopilot cluster** per region for the API/backend tier, deployed into the Shared VPC/subnet from the `network` module
- **Cloud Run services** for event-driven workloads (webhook ingestion, notification dispatch), scaling to zero by default
- A dedicated **service account per Cloud Run service** for Workload Identity Federation — no long-lived keys

## Usage

Depends on both `landing-zone` (project IDs) and `network` (VPC/subnet self-links).

```bash
cp terraform.tfvars.example terraform.tfvars
# fill network/subnetwork values from: terraform output (in ../network)

terraform init
terraform validate
terraform plan -out=compute.tfplan
```

## Design notes (why the code looks like this)

- **`enable_autopilot = true`, no node pool resources.** This is the direct implementation of ADR-003's Autopilot-over-Standard call — there's deliberately no `google_container_node_pool` resource in this module, since Autopilot manages node lifecycle. If a future GPU workload needs Standard mode, that's a new, separate cluster resource — not a change to this one (see ADR-003's "revisit if").
- **`min_instance_count = 0` on Cloud Run services by default.** This is the literal mechanism behind the "cost scales sub-linearly" NFR — idle event-driven services cost nothing between triggers. `max_instance_count = 50` is a starting ceiling, not a tuned value; revisit after real seasonal-spike data, same caveat as Cloud Armor's rate limit in the network module.
- **Per-service service accounts, not one shared identity.** Each Cloud Run service gets its own `google_service_account`, scoped to only what that specific service needs — this is least privilege applied at the workload level, not just the project level, matching the HIPAA-aligned NFR.

## Known limitation

Not yet run against a live org — same caveat as the landing-zone and network modules. This module has an added dependency chain: apply `landing-zone` → `network` → `compute` in that order, and feed each module's outputs into the next one's `.tfvars`. Validate the whole chain in a sandbox before touching a production org.

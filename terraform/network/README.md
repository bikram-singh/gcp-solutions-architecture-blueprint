# Network Module

Implements **ADR-002: Network Architecture**.

Builds:
- One **Network Connectivity Center (NCC) hub** in the `shared-services` project
- One **Shared VPC** per environment/region (spoke), each attached to the hub
- Service projects (from the `landing-zone` module output) attached as Shared VPC service projects — no direct VPC peering between them
- A **Cloud Armor** security policy: adaptive Layer 7 DDoS protection, per-IP rate limiting, and managed WAF rules (SQLi/XSS)

## Usage

This module consumes project IDs produced by the `landing-zone` module (ADR-001). Run `landing-zone` first.

```bash
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars: fill in the real project IDs from landing-zone's outputs

terraform init
terraform validate
terraform plan -out=network.tfplan
```

## Prerequisites

- The `landing-zone` module already applied — this module references its project IDs
- Terraform >= 1.7, `google` provider `~> 5.0`
- Credentials with `roles/compute.networkAdmin` and `roles/compute.securityAdmin` at the relevant projects, plus `roles/networkconnectivity.hubAdmin` on the hub project

## Design notes (why the code looks like this)

- **NCC hub, not VPC peering.** ADR-002's whole decision rests on avoiding non-transitive peering at scale — the `google_network_connectivity_spoke` resources are the direct implementation of that call.
- **One Shared VPC per region, not one global Shared VPC.** This preserves the residency boundary from ADR-001: an EU service project can only ever be a service project of the `prod-eu` host project, never `prod-us`. There's no code path that could accidentally attach it to the wrong region's VPC — the `service_projects_by_spoke` map is the enforcement point, and it's intentionally explicit (no computed cross-region logic) so a reviewer can read it directly.
- **Cloud Armor's rate limit threshold is a variable, not hardcoded**, because the "right" number depends on real traffic data you don't have until the platform is live — the default (3000 req/min/IP) is a reasonable starting point for an API tier, not a tuned value. Revisit after the first real seasonal spike.
- **`rate_based_ban` over a flat `deny`** — a legitimate client that briefly exceeds the threshold gets a temporary 429, not a permanent block, which matters for the "no manual intervention" NFR: you don't want an on-call engineer manually unbanning a partner clinic's IP during a traffic spike.

## Known limitation

Same as the landing-zone module: **not yet run against a live org**. Before applying:

1. `terraform validate` locally
2. Apply `landing-zone` first in a sandbox, capture its outputs, feed them into this module's `terraform.tfvars`
3. `terraform plan` against the sandbox, review the diff carefully — this module touches load-bearing connectivity, so a bad plan here has a larger blast radius than the landing-zone module did

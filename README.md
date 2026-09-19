# ðŸ¥ GCP Solutions Architecture Blueprint

**MedSecure** â€” a reference architecture for a multi-region healthcare SaaS platform on Google Cloud, built to demonstrate solutions-architecture-level decision-making, not just infrastructure delivery.

![Terraform](https://img.shields.io/badge/Terraform-1.7%2B-623CE4?logo=terraform&logoColor=white)
![GCP](https://img.shields.io/badge/GCP-Live%20Infrastructure-4285F4?logo=googlecloud&logoColor=white)
![HCP Terraform](https://img.shields.io/badge/HCP%20Terraform-Wired%20%26%20Proven-7B42BC?logo=terraform&logoColor=white)
![GitHub Actions](https://img.shields.io/badge/CI%2FCD-GitHub%20Actions-2088FF?logo=githubactions&logoColor=white)
![Pillars Live](https://img.shields.io/badge/pillars%20live-10%2F10-brightgreen)
![Deviations Documented](https://img.shields.io/badge/deviations%20documented-24-blue)
![DR Drilled](https://img.shields.io/badge/DR%20drill-RTO%20~4min%20%7C%20RPO%200-success)
![License](https://img.shields.io/badge/license-MIT-lightgrey)

> ðŸ“„ Companion article: *["From Runbooks to Architecture Decision Records: Becoming a GCP Solutions Architect"](#)* (link once published)

---

## ðŸ“‘ Table of Contents

- [Why this repo exists](#-why-this-repo-exists)
- [The scenario](#-the-scenario)
- [Architecture at a glance](#-architecture-at-a-glance)
- [Proof, not just claims](#-proof-not-just-claims)
- [Architecture diagrams](#-architecture-diagrams)
- [Repo structure](#-repo-structure)
- [Getting started](#-getting-started)
- [Related deep-dive articles](#-related-deep-dive-articles)
- [Status](#-status)

---

## ðŸŽ¯ Why this repo exists

A DevOps engineer proves they can build and operate what someone else designed. A Solutions Architect proves they can *decide* â€” weigh trade-offs, justify a pattern over its alternatives, and defend that decision against cost, security, reliability, and compliance pressure simultaneously.

This repo is that proof, structured as a single case study rather than a grab-bag of demos. Every architectural choice is traceable to a stated requirement and recorded as a formal decision, not just implemented.

It's also, deliberately, not a sanitized demo. Every module here was applied to a **real, live GCP organization** â€” not just written and left as `terraform plan`-clean theory. That meant hitting real API quirks, real IAM permission boundaries, real billing constraints, and even one real accidental-destroy incident along the way. Rather than hide any of that, it's all recorded in [`docs/known-deviations.md`](docs/known-deviations.md) â€” **24 entries**, most resolved with a genuine root cause found, a few left open with a precise, honest explanation of why. A reviewer can see not just the design, but exactly how it held up against a real cloud environment.

---

## ðŸ©º The scenario

**MedSecure** ingests patient-consented wearable telemetry, stores and analyzes it, and exposes a portal + APIs to partner clinics.

**Non-functional requirements driving every decision below:**

| Requirement | Target |
|---|---|
| ðŸŸ¢ API tier availability | 99.95% |
| â±ï¸ Recovery Point Objective | â‰¤ 15 min |
| â±ï¸ Recovery Time Objective | â‰¤ 1 hr |
| ðŸŒ Data residency | EU and US customer data must not cross region |
| ðŸ”’ Compliance | HIPAA-aligned controls (encryption, audit logging, least privilege) |
| ðŸ“ˆ Elasticity | Absorb 10x seasonal traffic spikes without manual intervention |
| ðŸ’° Cost | Infra cost scales sub-linearly with user growth |

ðŸ“˜ Full detail: [`docs/01-scenario-and-nfrs.md`](docs/01-scenario-and-nfrs.md)

---

## ðŸ—ï¸ Architecture at a glance

Structured around Google's six **Well-Architected Framework** pillars â€” see [`docs/02-well-architected-mapping.md`](docs/02-well-architected-mapping.md) for the full mapping and an honest self-rating scorecard.

| # | Pillar | ADR | Terraform | Status |
|---|---|---|---|---|
| 1 | ðŸ—‚ï¸ Landing Zone & Resource Hierarchy | [ADR-001](docs/adr/ADR-001-landing-zone.md) | [`terraform/landing-zone`](terraform/landing-zone) | ðŸŸ¢ **Live** â€” 8 folders, 4 org policies, 14 projects |
| 2 | ðŸŒ Network Architecture | [ADR-002](docs/adr/ADR-002-network.md) | [`terraform/network`](terraform/network) | ðŸŸ¢ **Live** â€” NCC hub, Shared VPC, Cloud Armor, PSA peering |
| 3 | âš™ï¸ Compute & Modernization | [ADR-003](docs/adr/ADR-003-compute.md) | [`terraform/compute`](terraform/compute) | ðŸŸ¢ **Live** â€” GKE Autopilot (private nodes), 2 Cloud Run services |
| 4 | ðŸ—„ï¸ Data & Analytics | [ADR-004](docs/adr/ADR-004-data.md) | [`terraform/data`](terraform/data) | ðŸŸ¢ **Live** â€” Cloud SQL, BigQuery, Pub/Sub, Dataplex + real, drilled DR |
| 5 | ðŸ¤– AI/ML Layer | [ADR-005](docs/adr/ADR-005-ai-ml.md) | [`terraform/ai-ml`](terraform/ai-ml) | ðŸŸ¢ **Live** â€” Vertex AI endpoint, Cloud Run agent |
| 6 | ðŸ” Security & Compliance | [ADR-006](docs/adr/ADR-006-security.md) | [`terraform/security`](terraform/security) | ðŸŸ¢ **Live** â€” VPC-SC perimeter, CMEK |
| 7 | ðŸ›Ÿ Reliability & Disaster Recovery | [ADR-007](docs/adr/ADR-007-reliability-dr.md) | [`terraform/reliability`](terraform/reliability) | ðŸŸ¢ **Live** â€” redesigned alerting + real drilled failover |
| 8 | ðŸ’µ Cost Optimization / FinOps | [ADR-008](docs/adr/ADR-008-cost.md) | [`terraform/cost`](terraform/cost) | ðŸŸ¢ **Live** â€” budget + notification channel |
| 9 | ðŸ” CI/CD & Infrastructure as Code | [ADR-009](docs/adr/ADR-009-cicd.md) | [`.github/workflows`](.github/workflows) + [`terraform/*`](terraform) | ðŸŸ¢ **Live** â€” 9 HCP Terraform workspaces, WIF auth, proven applies |
| 10 | ðŸ“Š Observability | [ADR-010](docs/adr/ADR-010-observability.md) | [`terraform/observability`](terraform/observability) | ðŸŸ¢ **Live** â€” SLO, burn-rate alerts, dashboard |

Each pillar has: an **ADR** (the decision + rejected alternatives, *plus* a real "Implementation Status" section added after the build), a **Terraform module**, and an **architecture diagram**. Every ADR's Implementation Status links back to the specific `known-deviations.md` entries for that pillar, so the design reasoning and the real-world outcome are never disconnected from each other.

---

## ðŸ”¬ Proof, not just claims

This section exists because a reference architecture is only as credible as the evidence behind it. Everything below is a real, reproducible result â€” not a description of intended behavior.

### ðŸš‘ A real, measured disaster recovery drill (Pillar 7)

Not a tabletop exercise â€” an actual `gcloud sql instances promote-replica` run against a live Cloud SQL primary and cross-region replica, with a real test write tracked through the whole process.

| Metric | Target | **Measured** |
|---|---|---|
| â±ï¸ RTO | â‰¤ 60 min | **~3â€“4 min** âœ… |
| ðŸ’¾ RPO | â‰¤ 15 min | **0** âœ… â€” the test write's timestamp matched exactly, byte-for-byte, after promotion |

ðŸ“˜ Full drill log, including the honest caveat that a single-write test understates RPO risk under sustained load: [`docs/dr-drill/failover-runbook.md`](docs/dr-drill/failover-runbook.md)

### ðŸ” A real, tested CI/CD pipeline (Pillar 9)

All 9 HCP Terraform workspaces were individually tested with a genuine `git push â†’ VCS trigger â†’ plan â†’ human approval â†’ apply` cycle, authenticated via a dedicated Workload Identity Federation pool and service account â€” no static keys anywhere in the chain.

| Result | Workspaces |
|---|---|
| âœ… Fully clean, zero-error applies | `network`, `observability`, `compute`, `ai-ml`, `security`, `reliability`, `cost` |
| âš ï¸ Correctly blocked on real, external, understood constraints | `landing-zone` (billing-account project-link quota â€” a trial-tier limit, not a bug), `data` (VPC-SC perimeter â€” confirmed to correctly block *any* unauthorized caller, local or remote, exactly as a security perimeter should) |

The GitHub `production` Environment protection rule (a required human reviewer before any prod apply) is genuinely active â€” verified directly via the GitHub API, not just described in a workflow YAML file that might not actually be enforced.

### ðŸš¨ Real incidents, caught and cleanly recovered

Two things went wrong during this build. Both are left in the record rather than edited out, because how a mistake gets caught and fixed says more about engineering judgment than a flawless run would:

- **An accidental `terraform apply` destroy.** Mid-session, a command intended to fix a quota-project setting instead destroyed 14 real GCP projects. Recovered with **zero data loss** using Terraform `import` blocks to reattach state to the recovered (undeleted) resources. This incident is also the direct, stated justification for Pillar 9's mandatory prod-apply human-approval gate â€” not a theoretical best practice, a lesson learned the hard way in this exact repo.
- **An unintentional shared-resource rename.** Importing an existing org-level VPC-SC Access Policy (owned by a separate, unrelated live project) briefly overwrote its display title during the same `apply` that correctly imported it. Caught and reverted within the same session, with the fix verified via a follow-up `terraform plan` showing zero drift.

ðŸ“˜ Full details on both, and everything else: [`docs/known-deviations.md`](docs/known-deviations.md) (24 entries total).

---

## ðŸ“ Architecture diagrams

| Pillar | Diagram |
|---|---|
| ðŸ—‚ï¸ Landing Zone | [`landing-zone-hierarchy.svg`](docs/diagrams/landing-zone-hierarchy.svg) |
| ðŸŒ Network | [`network-topology.svg`](docs/diagrams/network-topology.svg) |
| âš™ï¸ Compute | [`compute-architecture.svg`](docs/diagrams/compute-architecture.svg) |
| ðŸ—„ï¸ Data | [`data-architecture.svg`](docs/diagrams/data-architecture.svg) |
| ðŸ¤– AI/ML | [`ai-ml-architecture.svg`](docs/diagrams/ai-ml-architecture.svg) |
| ðŸ” Security | [`security-architecture.svg`](docs/diagrams/security-architecture.svg) |
| ðŸ›Ÿ Reliability/DR | [`dr-failover-architecture.svg`](docs/diagrams/dr-failover-architecture.svg) |
| ðŸ’µ Cost | [`cost-scaling.svg`](docs/diagrams/cost-scaling.svg) |
| ðŸ” CI/CD | [`cicd-pipeline.svg`](docs/diagrams/cicd-pipeline.svg) |
| ðŸ“Š Observability | [`observability-architecture.svg`](docs/diagrams/observability-architecture.svg) |
| ðŸ¢ **Real deployed hierarchy** | [`deployed-hierarchy.md`](docs/deployed-hierarchy.md) â€” the actual, live org structure (redacted IDs) |

---

## ðŸ“‚ Repo structure

```
.
â”œâ”€â”€ README.md
â”œâ”€â”€ docs/
â”‚   â”œâ”€â”€ 01-scenario-and-nfrs.md
â”‚   â”œâ”€â”€ 02-well-architected-mapping.md
â”‚   â”œâ”€â”€ deployed-hierarchy.md        # real, live org structure
â”‚   â”œâ”€â”€ known-deviations.md          # 24 documented real-world findings
â”‚   â”œâ”€â”€ adr/                         # 10 ADRs, each with a real Implementation Status
â”‚   â”œâ”€â”€ diagrams/                    # architecture diagrams per pillar
â”‚   â””â”€â”€ dr-drill/
â”‚       â”œâ”€â”€ failover-runbook.md      # real, measured drill results
â”‚       â””â”€â”€ scripts/
â”œâ”€â”€ terraform/
â”‚   â”œâ”€â”€ landing-zone/
â”‚   â”œâ”€â”€ network/
â”‚   â”œâ”€â”€ compute/
â”‚   â”œâ”€â”€ data/
â”‚   â”œâ”€â”€ ai-ml/
â”‚   â”œâ”€â”€ security/
â”‚   â”œâ”€â”€ reliability/
â”‚   â”œâ”€â”€ cost/
â”‚   â””â”€â”€ observability/
â”œâ”€â”€ .github/workflows/
â”‚   â”œâ”€â”€ terraform-plan.yml           # path-filtered plan-on-PR
â”‚   â””â”€â”€ terraform-apply.yml          # auto-apply non-prod, gated prod apply
â””â”€â”€ cost-model/
    â””â”€â”€ cost-model.csv               # itemized, ADR-linked cost model
```

Each `terraform/<module>/` includes its own `README.md` with design notes explaining *why* the code looks the way it does â€” not just what it does.

---

## ðŸš€ Getting started

Each module can be applied independently, but they have real dependencies on each other's outputs â€” apply in this order:

```bash
# 1ï¸âƒ£ Landing zone (no dependencies)
cd terraform/landing-zone
cp terraform.tfvars.example terraform.tfvars   # fill in your real org_id, billing_account
terraform init && terraform plan

# 2ï¸âƒ£ Network (needs landing-zone's project IDs)
cd ../network
cp terraform.tfvars.example terraform.tfvars
terraform init && terraform plan

# 3ï¸âƒ£+ Compute, Data, AI/ML, Security, Reliability, Cost, Observability
#     each needs the prior modules' real outputs -- see that module's own README.md
```

> âš ï¸ **Before applying anything for real, read [`docs/known-deviations.md`](docs/known-deviations.md) first.** It documents nearly every real API quirk, IAM permission gap, and org-policy interaction this build actually hit while applying against a live org â€” most of the friction you'd otherwise rediscover yourself the hard way is already mapped out there, with the exact fix.

---

## ðŸ”— Related deep-dive articles

This project builds directly on prior hands-on work, published separately:

- ðŸ›¡ï¸ **Cloud Armor** â€” WAF/DDoS/rate-limiting lab
- ðŸŒ **Network Connectivity Center** â€” hub-and-spoke connectivity lab
- ðŸ”’ **VPC Service Controls** â€” the 7-part perimeter lab this repo's Security pillar directly extends, including reusing its existing org-level Access Policy rather than creating a duplicate
- ðŸ“¡ **Streaming Telemetry Pipeline** â€” the Pub/Sub â†’ Dataflow â†’ BigQuery pipeline MedSecure's Data pillar design reuses
- ðŸ›ï¸ **FAST Foundation** â€” the GCP landing zone project whose real, pre-existing org resources (network host project, Access Policy) this build deliberately integrated with rather than duplicated

---

## âœ… Status

**All 10 pillars have real, applied infrastructure or a fully proven mechanism.** What began as an 8-week phased design roadmap (landing zone â†’ network â†’ security perimeter â†’ compute/data â†’ AI/ML â†’ reliability/DR â†’ cost â†’ documentation) is now substantially complete against a live GCP organization, not just on paper.

Two precisely-scoped items remain open, both understood and documented rather than mysterious:
- ðŸ”“ A **VPC Service Controls Access Level** is needed to complete Cloud SQL's cutover to fully private networking (the infrastructure for this â€” Private Service Access peering â€” is already live; only the perimeter access grant is missing).
- ðŸ’³ A **billing-account quota increase** (a trial-tier project-link limit) is pending approval before `landing-zone`'s full 14-project fleet can be billed and applied end-to-end through the CI/CD pipeline.

ðŸ“˜ Progress and full history tracked via the pillar table above and [`docs/known-deviations.md`](docs/known-deviations.md).


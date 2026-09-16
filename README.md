# GCP Solutions Architecture Blueprint

**MedSecure** — a reference architecture for a multi-region healthcare SaaS platform on Google Cloud, built to demonstrate solutions-architecture-level decision-making, not just infrastructure delivery.

> Companion article: *["From Runbooks to Architecture Decision Records: Becoming a GCP Solutions Architect"](#)* (link once published)

---

## Why this repo exists

A DevOps engineer proves they can build and operate what someone else designed. A Solutions Architect proves they can *decide* — weigh trade-offs, justify a pattern over its alternatives, and defend that decision against cost, security, reliability, and compliance pressure simultaneously.

This repo is that proof, structured as a single case study rather than a grab-bag of demos. Every architectural choice is traceable to a stated requirement and recorded as a formal decision, not just implemented.

---

## The scenario

**MedSecure** ingests patient-consented wearable telemetry, stores and analyzes it, and exposes a portal + APIs to partner clinics.

**Non-functional requirements driving every decision below:**

| Requirement | Target |
|---|---|
| API tier availability | 99.95% |
| Recovery Point Objective | ≤ 15 min |
| Recovery Time Objective | ≤ 1 hr |
| Data residency | EU and US customer data must not cross region |
| Compliance | HIPAA-aligned controls (encryption, audit logging, least privilege) |
| Elasticity | Absorb 10x seasonal traffic spikes without manual intervention |
| Cost | Infra cost scales sub-linearly with user growth |

Full detail: [`docs/01-scenario-and-nfrs.md`](docs/01-scenario-and-nfrs.md)

---

## Architecture at a glance

Structured around Google's six **Well-Architected Framework** pillars — see [`docs/02-well-architected-mapping.md`](docs/02-well-architected-mapping.md) for the full mapping.

| # | Pillar | Status |
|---|---|---|
| 1 | [Landing Zone & Resource Hierarchy](docs/adr/ADR-001-landing-zone.md) | ✅ Done |
| 2 | [Network Architecture](docs/adr/ADR-002-network.md) | ✅ Done |
| 3 | [Compute & Modernization](docs/adr/ADR-003-compute.md) | ✅ Done |
| 4 | [Data & Analytics](docs/adr/ADR-004-data.md) | ✅ Done |
| 5 | [AI/ML Layer](docs/adr/ADR-005-ai-ml.md) | ✅ Done |
| 6 | [Security & Compliance](docs/adr/ADR-006-security.md) | ✅ Done |
| 7 | [Reliability & Disaster Recovery](docs/adr/ADR-007-reliability-dr.md) | ✅ Done |
| 8 | [Cost Optimization / FinOps](docs/adr/ADR-008-cost.md) | ✅ Done |
| 9 | [CI/CD & Infrastructure as Code](docs/adr/ADR-009-cicd.md) | ⬜ Planned |
| 10 | [Observability](docs/adr/ADR-010-observability.md) | ⬜ Planned |

Each pillar has: an **ADR** (the decision + rejected alternatives), a **Terraform module**, and an **architecture diagram**.

---

## Repo structure

```
.
├── README.md
├── docs/
│   ├── 01-scenario-and-nfrs.md
│   ├── 02-well-architected-mapping.md
│   ├── adr/                     # one ADR per pillar
│   └── diagrams/                # whole-platform + per-pillar diagrams
├── terraform/
│   ├── landing-zone/
│   ├── network/
│   ├── compute/
│   ├── data/
│   ├── ai/
│   ├── security/
│   └── observability/
├── cost-model/                  # cost-per-1000-users spreadsheet
└── dr-drill/                    # failover drill runbook + recorded results
```

---

## Related deep-dive articles

This project builds directly on prior hands-on work, published separately:

- Cloud Armor — WAF/DDoS/rate-limiting lab
- Network Connectivity Center — hub-and-spoke connectivity
- VPC Service Controls — data exfiltration perimeter *(the strongest existing asset behind Pillar 6)*
- Streaming Telemetry Pipeline — Pub/Sub → Dataflow → BigQuery

---

## Status

🚧 Active build — following an 8-week phased roadmap (landing zone → network → security perimeter → compute/data → AI/ML → reliability/DR → cost → documentation). Progress tracked via the pillar table above.










# MedSecure: Scenario & Non-Functional Requirements

This document is the single source of truth for the case study every ADR in this repo is built against. Every architectural decision traces back to one or more of the requirements below — if a decision in an ADR doesn't obviously serve one of these, that's worth questioning.

---

## The business scenario

**MedSecure** is a multi-region healthcare SaaS platform. It:

- Ingests continuous, patient-consented telemetry from wearable devices (heart rate, activity, sleep patterns)
- Stores that telemetry alongside transactional data (patient accounts, clinic relationships, appointments, consent records)
- Runs analytics and anomaly detection over the telemetry stream
- Exposes a clinician-facing portal and partner-clinic APIs
- Operates in two residency-separated regions: the EU and the US, serving customers in each region exclusively from infrastructure in that region

It is intentionally a healthcare scenario — not because healthcare is trendy, but because healthcare forces hard trade-offs across compliance, disaster recovery, and security simultaneously, in a way a simpler CRUD app wouldn't. A reference architecture that only has to handle "make the website fast" doesn't demonstrate solution-architecture judgment the way one that also has to handle "never let EU patient data touch US infrastructure" does.

---

## Non-functional requirements (NFRs)

These are the actual constraints every ADR's decision has to satisfy. Where a decision's trade-off section says "accepted because X," X usually traces back to one of these.

| # | Requirement | Target | Primary pillar(s) affected |
|---|---|---|---|
| 1 | API tier availability | 99.95% | Compute (ADR-003), Reliability (ADR-007), Observability (ADR-010) |
| 2 | Recovery Point Objective (RPO) | ≤ 15 min | Data (ADR-004), Reliability (ADR-007) |
| 3 | Recovery Time Objective (RTO) | ≤ 1 hr | Reliability (ADR-007) |
| 4 | Data residency | EU and US customer data must never cross region | Landing Zone (ADR-001), Network (ADR-002), Data (ADR-004), Security (ADR-006) |
| 5 | Compliance | HIPAA-aligned: encryption at rest/in transit, audit logging, least privilege | Security (ADR-006), Landing Zone (ADR-001) |
| 6 | Elasticity | Absorb a 10x seasonal traffic spike (flu-season telemetry volume) without manual intervention | Network (ADR-002, Cloud Armor), Compute (ADR-003, autoscaling), Data (ADR-004, Pub/Sub) |
| 7 | Cost | Infrastructure cost scales sub-linearly with user growth | Cost (ADR-008) |

### Why each one matters, briefly

**Availability (99.95%)** is the number the Reliability pillar's DR strategy is actually tested against — the real drill measured an RTO of ~3–4 minutes against this NFR's implied downtime budget, dramatically inside target.

**RPO/RTO** together are what rule out a purely manual, undocumented failover process (Reliability ADR-007, Option B) — a target this specific and this tight needs a drilled, measured process, not an assumption.

**Data residency** is the single requirement with the widest blast radius across this repo. It's the reason the landing zone uses folder-per-region rather than a flat structure, the reason the network uses two independent VPC-SC perimeters rather than one shared perimeter, and the reason Cloud SQL's DR replica always pairs same-region (EU→EU, never EU→US).

**Compliance** is why every pillar defaults to the more conservative option when there's a choice — CMEK over default encryption, private networking over public IP (even when a real deviation temporarily broke this — see `docs/known-deviations.md`), and audit logging enabled explicitly rather than left at GCP's defaults.

**Elasticity** is the direct justification for Cloud Armor's adaptive rate limiting, Cloud Run's scale-to-zero-to-N-instances design, and Pub/Sub's inherent elasticity for the telemetry ingestion path — all three exist specifically because a flu-season spike is a real, anticipated event, not a hypothetical.

**Cost sub-linearity** is what the cost model in `cost-model/cost-model.csv` is built to demonstrate: fixed costs (DR replica, regional HA, SCC Premium) stay flat as user count grows, so cost-per-user falls — the model's whole point is showing *why* the curve bends, not just that it does.

---

## What's explicitly out of scope

To keep this a focused case study rather than an unbounded green-field build:

- Mobile app / wearable-device firmware — MedSecure's platform assumes telemetry already arrives via a defined API contract
- Patient-facing UI — only the clinician portal and partner-clinic APIs are in scope
- Billing/subscription management for clinics — assumed to be handled by a separate system
- A third region (APAC, etc.) — the architecture is *designed* to extend to a third region cleanly (see ADR-001's "revisit if" clause), but not built out

---

## How this maps to the real build

Every one of these NFRs now has a real answer, not just a design intention — see the "Implementation Status" section at the bottom of each ADR in [`docs/adr/`](adr/), and the full real-world build log in [`docs/known-deviations.md`](known-deviations.md).


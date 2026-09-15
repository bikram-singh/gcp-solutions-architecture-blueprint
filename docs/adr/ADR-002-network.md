# ADR-002: Network Architecture

**Status:** Accepted
**Pillar:** 2 — Network Architecture
**Date:** 2026-09-15

---

## Context

MedSecure's landing zone (ADR-001) gives every environment/region a clean project boundary, but those projects still need to talk to each other — the API tier needs to reach the data tier, both need reach into shared services (logging, the network hub), and everything needs a path in from the internet and out to on-prem partner clinic systems. The network design has to satisfy two NFRs simultaneously that pull in different directions: **99.95% availability** (which wants redundant, low-friction connectivity) and **data residency** (which wants EU and US traffic to stay structurally separated, not just conveniently separated).

**Requirements this decision must satisfy:**
- 99.95% availability for the API tier — no single connectivity path can be a hard dependency
- Absorb 10x seasonal traffic spikes without manual intervention (NFR) — the edge needs to protect backend capacity, not just the load balancer needs to scale
- EU/US data residency (NFR) — carried over from ADR-001; the network must not create an implicit path for EU traffic to transit US infrastructure or vice versa
- HIPAA-aligned least privilege — network admin duties need to be separable from workload deployment duties

---

## Options considered

**Option A — VPC Peering between all project VPCs (mesh)**
Every service project's VPC peers directly with every other VPC it needs to reach.
- ✅ Simple to understand for a small number of projects
- ❌ VPC Peering is **non-transitive** — if `api` peers with `network-hub` and `network-hub` peers with `data`, `api` cannot reach `data` through the hub. At 6+ service projects per environment (ADR-001's matrix), this forces a full mesh, which becomes an O(n²) management problem fast and is exactly the "manual intervention required to scale" failure mode the NFRs are trying to avoid.

**Option B — Shared VPC only, no hub-and-spoke layer**
One Shared VPC per environment, all service projects attach directly as service projects.
- ✅ Centralizes IP/subnet management, simpler than full mesh peering
- ❌ Collapses the eu/us separation from ADR-001 back into a single flat network unless you run *two* entirely separate Shared VPCs — which then reintroduces the transitivity problem from Option A the moment shared services (logging, hub) need to reach both
- ❌ No architectural distinction between "backbone/transit" traffic and "workload" traffic — a config error in one service project's routing has a larger blast radius

**Option C — Hub-and-spoke via Network Connectivity Center (NCC), with Shared VPC spokes**
A single NCC hub in the `shared-services` project; each environment/region's Shared VPC attaches as a spoke.
- ✅ NCC hub-and-spoke solves the transitivity problem structurally — spokes route through the hub without needing pairwise peering
- ✅ Shared VPC *within* each region folder keeps the eu/us residency boundary from ADR-001 intact — EU workloads only ever share a VPC with other EU workloads
- ✅ IAM splits cleanly: Network Admin role scoped to the hub project only; Service Project Admin scoped per region — matches the least-privilege requirement
- ❌ More moving parts than Option A for a small deployment — only pays off once you're past ~4-5 spokes, which MedSecure already is per the ADR-001 project matrix

---

## Decision

**Option C** — NCC hub-and-spoke, with one Shared VPC per environment/region acting as a spoke.

The deciding factor: only Option C keeps the residency boundary from ADR-001 intact *and* avoids the transitivity trap, at the same time. Options A and B each solve one problem while quietly breaking the other.

```
                     ┌─────────────────────────┐
                     │   NCC Hub (shared-services)│
                     │   medsecure-network-hub  │
                     └────────────┬─────────────┘
                    spoke          │          spoke
           ┌────────────────────┐ │ ┌────────────────────┐
           │ Shared VPC: prod-eu │ │ │ Shared VPC: prod-us │
           │ (host: medsecure-  │ │ │ (host: medsecure-  │
           │  eu-network)       │ │ │  us-network)       │
           └─────────┬──────────┘ │ └─────────┬──────────┘
                     │             │           │
        ┌────────────┼───────┐    │  ┌─────────┼───────────┐
        │            │       │    │  │         │           │
   medsecure-    medsecure- medsecure-    medsecure-  medsecure-
   eu-api        eu-data    eu-ml    us-api      us-data     us-ml
   (service      (service   (service (service    (service    (service
    project)      project)   project) project)    project)    project)
```

**Edge:**
- Global External HTTPS Load Balancer in front of each region's API tier
- **Cloud Armor** WAF + adaptive protection + rate limiting attached to the load balancer backend — directly answers the "10x traffic spike without manual intervention" NFR, since rate limiting and adaptive protection engage automatically, no on-call paging required
- No public IPs on backend tiers — Private Service Connect / Private Google Access for all managed-service access

**Hybrid connectivity:**
- Cloud Interconnect (partner) for production traffic to on-prem partner clinic systems — chosen over VPN as the primary path for its SLA guarantee, which the 99.95% availability NFR needs
- Cloud VPN kept as an automatic failover path, not the primary — this is the redundancy the availability NFR requires, at lower cost than dual Interconnects

---

## Consequences

**Accepted trade-offs:**
- The hub becomes a structurally important shared dependency — mitigated by keeping it deliberately minimal (routing and connectivity only, per ADR-001's shared-services scoping) and by the VPN failover path meaning a hub-adjacent Interconnect failure doesn't take down connectivity entirely
- More Terraform state and IAM surface than a simple peering mesh — accepted because it's what makes the design scale past MedSecure's current 6-service-project footprint without a redesign

**What this unlocks for later pillars:**
- ADR-006 (Security): VPC Service Controls perimeters map cleanly onto each region's Shared VPC spoke, since the spoke boundary already matches the residency boundary from ADR-001
- ADR-007 (Reliability/DR): the hub-and-spoke topology means adding a DR region later is "add another spoke," not a redesign

**Revisit if:** traffic patterns show the hub becoming a latency bottleneck for high-volume EU↔US shared-service calls (expected to be rare, since customer-facing workload traffic should never need to cross the residency boundary in the first place — if it does, that's a compliance issue to fix, not a network one).

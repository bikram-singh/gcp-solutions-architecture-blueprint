# ADR-010: Observability

**Status:** Accepted
**Pillar:** 10 — Observability
**Date:** 2026-09-15

---

## Context

This is the last pillar, and it's deliberately a synthesis one rather than a greenfield decision: Pillar 7 already built an uptime check and alert policy for the DR failover trigger; Pillar 8 already built budget alerts for the FinOps review cadence; every compute and AI/ML resource across Pillars 3 and 5 already emits Cloud Monitoring metrics by default just by existing on GCP's managed platforms. The risk at this stage of a build isn't a missing capability — it's ending up with observability scattered across eight disconnected per-pillar configurations, each useful in isolation but adding up to no coherent picture of "is the platform healthy right now."

**Requirements this decision must satisfy:**
- 99.95% availability for the API tier (NFR) — needs a defined SLO and error budget, not just raw uptime metrics nobody is watching against a target
- Absorb 10x seasonal traffic spikes without manual intervention (NFR) — observability needs to show *whether* the automatic scaling mechanisms built in Pillars 2, 3, and 4 are actually working during a spike, not just that a spike happened
- HIPAA-aligned audit logging (NFR, carried from ADR-006) — security-relevant log events need to be visible through the same observability surface, not siloed away from operational monitoring

---

## Options considered

**Option A — Per-service dashboards, one per Cloud Run/GKE/Cloud SQL resource**
A separate Cloud Monitoring dashboard for every individual resource across all 8 prior pillars.
- ✅ Maximum detail per resource
- ❌ Doesn't answer the actual question an on-call engineer or an executive needs answered during an incident ("is the platform healthy") — it answers twenty narrower questions instead, none of which is the one that matters first. This is the same "match the tool to the actual question" mistake this project has avoided in every other pillar (e.g., ADR-003's compute split by workload shape, not by every possible dimension)

**Option B — No dedicated observability pillar; rely on each prior pillar's individual monitoring resources as sufficient**
Treat Pillar 7's uptime check and Pillar 8's budget alerts as observability "done."
- ✅ Zero additional work
- ❌ Neither of those two prior pillars' monitoring resources says anything about the *golden signals* (latency, traffic, errors, saturation) for the actual customer-facing API tier — they cover DR triggering and cost, not day-to-day operational health, which is a real, unaddressed gap

**Option C — Golden-signals dashboards per pillar-relevant domain (not per resource), SLO/error-budget definitions tied to the 99.95% NFR, and a single platform-health view that surfaces Pillar 7's DR alerting and Pillar 8's budget alerting alongside operational metrics**
Dashboards organized around what a human actually needs to know (API health, data pipeline health, security posture, cost trend) rather than one dashboard per Terraform resource; a formal SLO definition with burn-rate alerting for the API tier; log-based metrics for the security-relevant events ADR-006 requires visibility into.
- ✅ Answers the actual operational question directly, same principle as every prior pillar's "match the solution to what's actually being asked" discipline
- ✅ SLO/error-budget definition makes the 99.95% NFR a *monitored*, *alertable* target — not just a design intention stated once in a requirements document and never checked again
- ✅ Explicitly incorporates rather than duplicates Pillar 7 and Pillar 8's existing monitoring resources, avoiding the fragmentation Option B risks and the over-granularity Option A risks
- ❌ Requires deciding what counts as a "golden signal" for a non-obvious domain like the AI/ML layer (agent query latency? grounding accuracy? both?) — a real design question this ADR has to answer, not a cost to dismiss

---

## Decision

**Option C** — domain-organized golden-signals dashboards, a formal SLO for the API tier, and explicit integration of the reliability and cost pillars' existing alerting.

The deciding factor is consistency with the discipline every prior pillar in this project applied: pick the tool that answers the actual operational question, not the one that produces the most dashboards. A platform-health view organized by domain is what an on-call engineer, a security reviewer, and a FinOps reviewer each actually need — not the same twenty per-resource panels re-sorted three different ways.

```
Dashboard: API Tier Golden Signals (the primary on-call view)
├── Latency  (p50/p95/p99, GKE + Cloud Run)
├── Traffic  (request rate, correlated against the Cloud Armor
│             rate-limit threshold from ADR-002 -- shows whether
│             the 10x seasonal spike NFR is actually holding)
├── Errors   (4xx/5xx rate)
└── Saturation (HPA scaling events, queue depth --
              same metric ADR-003's autoscaling already keys on)

SLO: 99.95% availability, API tier
  Error budget: burn-rate alerting at fast (1hr) and slow (6hr) windows
  -- ties the NFR directly to an alertable, checkable target rather
     than a document-only claim

Dashboard: Data Pipeline Health
├── Pub/Sub backlog (telemetry ingestion lag)
├── Dataflow job health (from the reused streaming pipeline)
└── BigQuery slot/query performance

Dashboard: Security & Compliance Posture
├── SCC Premium findings (from ADR-006's export)
├── Log-based metrics on Data Access audit log events
│   (the HIPAA-relevant visibility ADR-006 required)
└── VPC-SC perimeter violation attempts (if any)

Dashboard: Platform Health Summary (the executive/status-check view)
├── DR trigger status (surfaces Pillar 7's alert policy directly --
│                       not duplicated, just displayed here too)
├── Budget burn-down (surfaces Pillar 8's budget alert directly)
└── Overall SLO error-budget remaining
```

**Golden signals for the AI/ML layer specifically** (the genuine design question Option C's weakness named): latency and traffic are straightforward (agent response time, query volume); "errors" is defined as grounding failures (the agent unable to answer from retrieved data, per ADR-005's design) rather than just HTTP error codes, since a 200-status response with a hallucinated or ungrounded answer is a real failure this platform cares about that a generic error-rate metric wouldn't catch.

---

## Consequences

**Accepted trade-offs:**
- Domain dashboards require deciding what belongs in each one — a design decision with real judgment involved, not a purely mechanical rollup of existing metrics — accepted as worthwhile effort, since a badly-organized dashboard is barely better than no dashboard
- SLO burn-rate alerting requires tuning the fast/slow window thresholds against real traffic patterns MedSecure doesn't have yet — same "revisit once real usage data exists" caveat as the Cloud Armor rate limit (ADR-002) and Cloud Run max-instances (ADR-003) before it

**What this unlocks for the project as a whole:**
- This is the last pillar — with it, all ten Well-Architected Framework areas from Section 3 of the original project plan have a corresponding ADR, and the self-review scorecard in the deliverables checklist can now be honestly filled in against ten real decisions, not aspirational ones
- The Platform Health Summary dashboard is a natural, concrete artifact for the Medium article's architecture walkthrough — a single screenshot that visibly ties together DR, cost, and SLO signals in one place

**Revisit if:** real production usage reveals a golden signal this design missed — most likely candidate, per the AI/ML section above, is that "grounding failure" needs a more precise definition once real clinician query patterns exist to observe.

---

## Implementation Status (updated after real build)

**Live.** Monitoring service, SLO, both burn-rate alert policies, and the dashboard all applied to `medsecure-eu-api-prod`. The dashboard JSON required four rounds of real GCP schema fixes (tile `title` placement, explicit `xPos`/`yPos`/`width`/`height`, and a `columns` value on the mosaic layout) -- none of which are obvious from the Terraform provider's own documentation. Verified with a clean, zero-drift HCP Terraform apply.

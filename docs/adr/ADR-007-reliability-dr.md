# ADR-007: Reliability & Disaster Recovery

**Status:** Accepted
**Pillar:** 7 — Reliability & Disaster Recovery
**Date:** 2026-09-15

---

## Context

ADR-004 already provisioned a cross-region Cloud SQL replica, marked as a failover target, for exactly this purpose — but a replica that's never been tested is a hope, not a DR strategy. This pillar's job is to turn that infrastructure into an actual, defined, testable plan: what triggers failover, who executes it, what "recovered" means precisely, and — critically — a real drill with real numbers, not just a design on paper.

**Requirements this decision must satisfy:**
- RPO ≤ 15 min, RTO ≤ 1 hr for the primary datastore (NFR) — this pillar is where these numbers get tested against reality, not just designed for
- 99.95% availability for the API tier (NFR) — DR strategy has to account for the compute and network layers recovering in step with data, not just the database alone
- EU/US data residency (NFR) — carried through from every prior pillar: failover must never cross the residency boundary, confirmed already by ADR-004's same-region replica pairing (`prod-eu` → `europe-west4`, `prod-us` → `us-east1`)

---

## Options considered

**Option A — Active-active across regions**
Run both regions as live, simultaneously serving traffic, with data synchronously replicated.
- ✅ Near-zero RTO — no failover event needed, since both regions are already serving
- ❌ Cloud SQL doesn't support true multi-region active-active writes without a much more complex architecture (e.g., Spanner or a custom conflict-resolution layer) — adopting this would mean replacing the OLTP decision from ADR-004 entirely, not extending it
- ❌ Meaningfully higher cost (double the always-on write capacity) for a requirement (RTO ≤ 1 hr) that doesn't actually demand it — active-active solves a stricter problem than MedSecure has

**Option B — Active-passive with manual failover**
Cross-region replica exists (as built in ADR-004), but promotion is a fully manual, undocumented process run ad hoc when needed.
- ✅ Cheapest option, no additional engineering
- ❌ An undocumented, untested manual process is the single most common cause of DR failure in real incidents — "we have a replica" is not the same claim as "we can recover within RTO," and there's no way to know the gap between those two claims without a drill
- ❌ Fails the credibility bar this whole project is built around: a DR strategy nobody has ever executed isn't meaningfully different from not having one

**Option C — Active-passive with a documented, drilled failover runbook and measured RTO/RPO**
Keep the cross-region replica from ADR-004; add an explicit, versioned runbook; actually run the failover drill and record real numbers.
- ✅ Matches MedSecure's actual requirement (RTO ≤ 1 hr, not near-zero) without Option A's cost and architectural complexity
- ✅ The drill is the credibility mechanism — a measured number ("failover completed in 42 minutes against a 60-minute target") is a claim that can be independently verified, unlike a stated design intention
- ❌ Still involves real downtime during an actual failover event (bounded by the RTO target, but non-zero) — accepted, since MedSecure's NFR explicitly allows for it and Option A's alternative isn't proportionate to the actual requirement

---

## Decision

**Option C** — active-passive with a documented, drilled runbook and measured results.

The deciding factor: MedSecure's stated RTO (≤ 1 hr) does not require active-active's cost and complexity, and a DR plan's real value comes from having actually been exercised, not from its design elegance. This is the same "match the solution to the actual requirement" discipline that drove ADR-003 (Autopilot over Standard) and ADR-004 (Cloud SQL split from BigQuery) — reaching for the more powerful, more expensive option when the stated requirement doesn't demand it is itself a design mistake worth naming and avoiding.

```
Primary: medsecure-eu-sql (europe-west1)
    │  continuous replication (point-in-time recovery enabled, ADR-004)
    ▼
DR Replica: medsecure-eu-sql-dr-replica (europe-west4, failover_target=true)

  ┌─────────────────────────────────────────────────────────┐
  │  Failover Runbook (docs/dr-drill/failover-runbook.md)     │
  │  1. Detect: Cloud Monitoring alert on primary unavailable  │
  │  2. Declare: on-call confirms incident, starts the clock   │
  │  3. Promote: gcloud sql instances promote-replica          │
  │  4. Re-point: update connection strings / DNS to new       │
  │     primary (automated via a documented script, not manual │
  │     find-and-replace under pressure)                       │
  │  5. Verify: run a defined smoke-test query set              │
  │  6. Confirm: mark incident resolved, record actual RTO/RPO │
  └─────────────────────────────────────────────────────────┘

  US region: identical, independent runbook and replica pairing
  (us-central1 -> us-east1) -- never crosses into the EU pairing
```

**The drill itself is the deliverable, not just the runbook.** Section 5 below documents the actual drill run against the sandbox org, with real timings — this is the artifact that gives this pillar its credibility, in both the repo and the article.

---

## Consequences

**Accepted trade-offs:**
- Non-zero downtime during an actual failover (bounded by RTO, not eliminated) — accepted as proportionate to MedSecure's actual requirement, not a shortfall against it
- The replica sits mostly idle in steady state, which is pure cost with no throughput benefit day-to-day — accepted as the direct price of the RTO/RPO guarantee; this is called out explicitly in Pillar 8's cost model rather than treated as a free resource

**What this unlocks for later pillars:**
- ADR-008 (Cost): the DR replica's steady-state cost needs to appear explicitly in the cost-per-1000-users model, not be absorbed silently
- ADR-010 (Observability): the Cloud Monitoring alert that triggers step 1 of the runbook is a concrete SLO/alerting requirement this pillar hands directly to Observability

**Revisit if:** a future business requirement tightens RTO below what active-passive can realistically deliver — at that point, Option A's active-active complexity becomes justified by the requirement itself, not adopted preemptively.

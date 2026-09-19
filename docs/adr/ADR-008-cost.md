# ADR-008: Cost Optimization / FinOps

**Status:** Accepted
**Pillar:** 8 — Cost Optimization / FinOps
**Date:** 2026-09-15

---

## Context

Every prior pillar made a cost trade-off in passing — GKE Autopilot over Standard (ADR-003), Cloud Run scale-to-zero for event-driven services (ADR-003, ADR-005), an idle DR replica (ADR-007), CMEK key management and SCC Premium (ADR-006). None of those decisions were free, and this pillar's job is to make the accumulated cost picture explicit rather than leave it scattered and implicit across six other documents. A cost model that only appears at the end of a build, disconnected from the decisions that drove it, is much less credible than one that traces every line item back to a named architectural choice.

**Requirements this decision must satisfy:**
- Infra cost must scale sub-linearly with user growth (NFR) — this pillar is where that claim gets tested against an actual model, not just asserted
- The cost model must account honestly for standing costs from every prior pillar (regional HA, DR replica, CMEK, SCC Premium) — not just showcase the scale-to-zero wins while hiding the always-on costs

---

## Options considered

**Option A — Optimize for lowest possible steady-state cost, accept availability trade-offs**
Drop regional HA on Cloud SQL, remove the DR replica, downgrade SCC to the free tier.
- ✅ Meaningfully cheaper
- ❌ Directly reverses decisions already made and justified against NFRs in ADR-004, ADR-006, and ADR-007 — the 99.95% availability and RTO/RPO targets aren't optional extras, they're stated requirements. Optimizing cost by quietly weakening a committed NFR isn't cost optimization, it's requirement erosion disguised as one

**Option B — No formal cost governance; rely on default GCP billing alerts only**
Skip committed-use discounts, rightsizing review, and a structured cost model; just watch the bill.
- ✅ Zero additional engineering effort
- ❌ Fails the NFR outright — "infra cost scales sub-linearly with user growth" is a claim that needs a model to support it, not an assumption. Without a cost-per-user calculation, there's no way to know whether the architecture actually satisfies this requirement or just happens to look affordable at current (near-zero) scale

**Option C — A committed-use + rightsizing strategy for predictable baseline load, on-demand/scale-to-zero for burst, and an explicit cost-per-1,000-users model that names every standing cost from prior pillars**
Apply committed use discounts to GKE/Cloud SQL baseline capacity; keep Cloud Run and BigQuery on-demand pricing where usage is genuinely bursty; build a cost model that explicitly line-items the DR replica, CMEK, and SCC Premium costs rather than omitting them.
- ✅ Matches spend pattern to actual usage shape — same "right tool for the actual shape of the thing" principle as ADR-003's compute split
- ✅ The explicit line-itemization of "expensive but justified" costs (DR replica, SCC Premium) is what makes this pillar's honesty credible — a cost model that only shows savings and never shows the deliberate spend is not trustworthy
- ❌ Requires ongoing FinOps discipline (a monthly review cadence) rather than a one-time setup — accepted as the necessary cost of the NFR actually being true on an ongoing basis, not just at design time

---

## Decision

**Option C** — committed-use + rightsizing for baseline, on-demand for burst, and an honest, itemized cost model.

The deciding factor: this pillar exists specifically to make cost trade-offs explicit and traceable, and Option A and B both fail that job in opposite ways — A by quietly reversing prior commitments, B by not measuring anything at all. Option C is the only one that treats cost as a first-class, honestly-modeled constraint alongside the NFRs already established, rather than either sacrificing them or ignoring the question.

## Cost model: cost per 1,000 active users

The model below is **illustrative, not a quoted GCP price** — actual figures depend on region, committed-use terms, and real usage patterns that don't exist yet at MedSecure's current (pre-launch) stage. What matters architecturally is the *shape* of the curve, not the specific numbers: costs split into a **near-fixed baseline** (doesn't grow with users) and a **variable component** (scales with usage), and the sub-linear NFR is satisfied because the fixed baseline is amortized across a growing user count.

| Cost category | Scaling behavior | Driving decision |
|---|---|---|
| GKE Autopilot (API/backend) | Scales with request volume via HPA | ADR-003 |
| Cloud Run (event-driven) | Scales to zero between triggers — near-zero at low volume | ADR-003, ADR-005 |
| Cloud SQL primary (regional HA) | **Fixed** — doesn't grow with users until a tier upgrade is needed | ADR-004 |
| Cloud SQL DR replica | **Fixed, idle in steady state** — pure cost, no throughput benefit day-to-day | ADR-007 |
| BigQuery | Scales with query volume (on-demand) or fixed (if slot-reserved) | ADR-004 |
| CMEK / Cloud KMS | **Near-fixed** — key operations cost is small relative to key management overhead | ADR-006 |
| SCC Premium | **Fixed** — priced per-asset/org-level, not per-user | ADR-006 |
| Vertex AI (agent + anomaly model) | Scales with query volume | ADR-005 |

**Why this satisfies the sub-linear NFR:** at 1,000 users, the fixed-cost rows (Cloud SQL HA + DR replica + CMEK + SCC Premium) dominate the total — cost-per-user is comparatively high. At 100,000 users, those same fixed costs are unchanged, while only the variable rows (GKE, Cloud Run, BigQuery, Vertex AI) grow — so cost-per-user drops. The curve is sub-linear specifically *because* the DR/security investment is fixed, not because those costs are small.

**FinOps practices applied:**
- Committed Use Discounts on the GKE and Cloud SQL baseline capacity that ADR-003/004 already established as steady, predictable load
- Budget alerts + the Recommender API for idle-resource cleanup, reviewed on a monthly cadence
- Showback (not chargeback) reporting per region, so the eu/us cost split stays visible without needing actual inter-team billing

---

## Consequences

**Accepted trade-offs:**
- The DR replica and SCC Premium remain real, named costs that don't disappear under scrutiny — this ADR deliberately doesn't try to make them look cheaper than they are, since doing so would undermine the honesty this pillar is supposed to bring to the rest of the project
- Committed Use Discounts require a forecast commitment (typically 1-3 years) — a real business risk if MedSecure's actual growth diverges from the model, noted here rather than glossed over

**What this unlocks for later pillars:**
- ADR-009 (CI/CD): a cost-conscious pipeline can gate on Infracost-style plan-time cost estimation before apply, catching an accidental expensive resource before it ships
- The Medium article's "what I'd do differently" section has a natural, honest answer here: at MedSecure's actual (near-zero) current user count, the fixed DR/security costs are disproportionately expensive relative to revenue — a real trade-off worth naming rather than hiding

**Revisit if:** real usage data eventually shows the sub-linear assumption doesn't hold at the scale MedSecure actually reaches — at that point, the cost model in this document should be replaced with real billing data, not left as illustrative numbers indefinitely.

---

## Implementation Status (updated after real build)

**Live.** Budget and notification channel applied to the billing account. What was initially mis-diagnosed as a "platform limitation" on budget creation turned out to be two distinct, real, fixable issues: a hardcoded USD currency on an INR-denominated billing account, and a missing `roles/billing.admin` grant (`roles/billing.user` does not include budget permissions) -- both found and corrected. See known-deviations.md #10/#12/#23/#24 for the full diagnostic trail.

# ADR-006: Security & Compliance

**Status:** Accepted
**Pillar:** 6 — Security & Compliance
**Date:** 2026-09-15

---

## Context

Every prior pillar has made individual security decisions in passing — region-scoped IAM in ADR-001, private-only networking in ADR-002, Workload Identity Federation in ADR-003, column-level PII tags in ADR-004, analyst-equivalent agent access in ADR-005. This pillar is where those individual decisions get formalized into an explicit, platform-wide security posture, and where the remaining gaps — data exfiltration prevention, encryption key ownership, secret handling, and continuous threat detection — get addressed directly.

This pillar reuses the existing VPC Service Controls lab (a 7-part hands-on build) as its foundation — that lab's perimeter design is treated as proven, and this ADR focuses on how it scales to MedSecure's multi-region, multi-project footprint and what else needs to sit alongside it.

**Requirements this decision must satisfy:**
- HIPAA-aligned controls: encryption at rest/in transit, audit logging, least privilege (NFR) — this is the pillar where "HIPAA-aligned" stops being a phrase and becomes a specific, checkable set of controls
- EU/US data residency (NFR) — the security perimeter must reinforce the residency boundary, not just the network and IAM layers established earlier
- No single point of credential compromise should expose patient data — the containment principle from ADR-005 (agent gets analyst-equivalent access) needs a platform-wide equivalent

---

## Options considered

**Option A — Rely on IAM and network controls alone (no VPC-SC perimeter)**
Trust the least-privilege IAM grants and private-networking decisions from ADR-001–005 as sufficient.
- ✅ Simplest option, nothing new to build
- ❌ IAM and network controls prevent *unauthorized access* but don't prevent *authorized* data from being exfiltrated to an external destination — a compromised or misconfigured credential with legitimate BigQuery read access could still copy patient data to a personal Google Cloud project or public bucket. This is precisely the gap VPC Service Controls exists to close, and leaving it unaddressed would be a real, named weakness in a HIPAA-context architecture

**Option B — Single VPC-SC perimeter around the entire organization**
Wrap every MedSecure project, in every region, in one perimeter.
- ✅ Maximum protection, simplest single perimeter to reason about
- ❌ Collapses the eu/us separation this entire architecture has structurally maintained since ADR-001 — a single perimeter doesn't distinguish between EU and US data movement within it, so an EU service could technically move data to a US project inside the same perimeter without tripping any control. This directly undermines the residency NFR that every prior pillar went out of its way to enforce structurally

**Option C — Per-region VPC-SC perimeters (extending the existing lab's design), plus CMEK, Secret Manager, and Security Command Center platform-wide**
One perimeter per region (`prod-eu`, `prod-us`), matching the folder/network/data boundaries already established; customer-managed encryption keys on all data stores; centralized secret management; continuous posture monitoring via SCC Premium.
- ✅ The perimeter boundary matches every other boundary in the architecture — region folder, Shared VPC spoke, BigQuery dataset location, and now VPC-SC perimeter all draw the same line, so residency is enforced at every layer consistently, not just some
- ✅ Extends the validated 7-part VPC-SC lab design rather than redesigning perimeter logic from scratch
- ✅ CMEK, Secret Manager, and SCC address the encryption, secret-handling, and detection gaps that IAM/network/perimeter controls alone don't cover
- ❌ Two perimeters to manage instead of one, and cross-perimeter access (e.g., a legitimate need for aggregate cross-region reporting) requires explicit perimeter bridges rather than being implicitly available — this is treated as a feature, not a cost: any cross-region data movement should require an explicit, auditable decision, not be a silent side effect of a shared perimeter

---

## Decision

**Option C** — per-region VPC-SC perimeters, plus CMEK, Secret Manager, and Security Command Center applied platform-wide.

The deciding factor is the same one that has driven every prior pillar: the security boundary should match the residency boundary, structurally, everywhere. A single global perimeter (Option B) would be the one place in the entire architecture where that discipline breaks down — and the whole point of this ADR is to close remaining gaps, not introduce a new one.

```
┌─────────────────────── VPC-SC Perimeter: prod-eu ───────────────────────┐
│  Projects: medsecure-eu-api-prod, medsecure-eu-data-prod,                │
│            medsecure-eu-ml-prod                                          │
│  Restricted services: BigQuery, Cloud SQL, Cloud Storage, Vertex AI      │
│  (extends the 7-part VPC-SC lab's perimeter design directly)            │
└────────────────────────────────────────────────────────────────────────┘

┌─────────────────────── VPC-SC Perimeter: prod-us ───────────────────────┐
│  Projects: medsecure-us-api-prod, medsecure-us-data-prod,                │
│            medsecure-us-ml-prod                                          │
│  Restricted services: BigQuery, Cloud SQL, Cloud Storage, Vertex AI      │
└────────────────────────────────────────────────────────────────────────┘

  No implicit bridge between the two perimeters. Any legitimate cross-
  region need (e.g. global cost reporting) requires an explicit, reviewed
  perimeter bridge rule -- an auditable decision, not a silent default.

Platform-wide, both perimeters:
├── CMEK on BigQuery, Cloud SQL, and GCS -- customer-managed key rotation
│   policy, keys held in Cloud KMS, scoped per region (EU keys never
│   leave EU, matching the same residency discipline as everything else)
├── Secret Manager for all credentials/API keys -- automatic rotation,
│   nothing in Terraform state or environment variables
└── Security Command Center Premium -- continuous posture management +
    threat detection across every project, feeding the audit log export
    pattern from ADR-001's shared-services logging project
```

**Audit logging:** Cloud Audit Logs (Admin Activity + Data Access, the latter explicitly enabled — it's off by default and easy to miss) exported from every project to the `medsecure-logging` project's locked-down bucket established in ADR-001, giving one place to review access history platform-wide without breaking the per-region perimeter isolation.

---

## Consequences

**Accepted trade-offs:**
- Two perimeters mean twice the perimeter configuration to maintain and twice the potential for a misconfigured access-level rule — mitigated by keeping the perimeter Terraform module structurally identical between regions (parameterized by region, not hand-written twice), so a review of one is effectively a review of both
- No default cross-region data flow means legitimate cross-region needs (global reporting, cost aggregation) require deliberate engineering work to bridge perimeters safely — accepted as the correct cost: the alternative is a residency violation waiting to happen the first time someone needs a "quick" cross-region query

**What this unlocks for later pillars:**
- ADR-007 (Reliability/DR): the DR replica pairing already established (EU→EU, US→US) means failover never has to cross a VPC-SC perimeter boundary either — one more layer where the residency discipline pays off during an actual incident
- ADR-008 (Cost): CMEK key management and SCC Premium have real cost implications that the cost model needs to account for explicitly, not treat as free

**Revisit if:** a genuine, approved business need for cross-region aggregate data emerges — at that point, design an explicit perimeter bridge with its own access-level review, rather than loosening either perimeter's boundary generally.

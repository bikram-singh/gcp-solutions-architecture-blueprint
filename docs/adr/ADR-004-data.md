# ADR-004: Data & Analytics

**Status:** Accepted
**Pillar:** 4 — Data & Analytics
**Date:** 2026-09-15

---

## Context

MedSecure ingests continuous wearable telemetry from patients, needs a transactional store for portal/API state (appointments, clinic accounts, consent records), and needs an analytics layer clinicians and the ML pipeline (Pillar 5) can query. Three distinct data shapes — transactional, streaming, analytical — each want a different service, and getting the boundaries wrong either overloads one system or creates unnecessary data-movement complexity between three separate ones.

This pillar reuses the streaming ingestion pattern already built and validated in the standalone streaming telemetry pipeline project — that pipeline's design decisions (Pub/Sub → Dataflow → BigQuery) are treated here as proven, not re-litigated from scratch, and this ADR focuses on how it integrates with the rest of MedSecure's architecture.

**Requirements this decision must satisfy:**
- RPO ≤ 15 min for the primary datastore (NFR) — the transactional store needs a replication/backup story that meets this directly
- EU/US data residency (NFR) — carried through from ADR-001/002; datasets must not be queryable across the residency boundary
- HIPAA-aligned least privilege + audit logging (NFR) — column-level access control for PII/PHI fields, not just dataset-level
- Absorb 10x seasonal traffic spikes (NFR) — the ingestion path specifically, since wearable telemetry volume is the most spike-prone data source

---

## Options considered

**Option A — Single database for everything (Cloud SQL for OLTP + analytics)**
Run analytical queries directly against the same Cloud SQL instance serving the transactional portal.
- ✅ Simplest possible architecture, one system to operate
- ❌ Analytical queries (aggregations across months of telemetry) compete for the same compute/IO as transactional reads/writes serving the live portal — directly threatens the 99.95% availability NFR for the API tier, since a heavy report query could degrade portal latency
- ❌ No natural fit for high-volume streaming ingestion; Cloud SQL isn't designed for continuous high-throughput writes at wearable-telemetry scale

**Option B — BigQuery for everything, including transactional state**
Use BigQuery as the single datastore, including for portal/account state.
- ✅ Excellent for analytics, scales effortlessly for the telemetry volume
- ❌ BigQuery is not built for low-latency point lookups/updates (a clinician updating one appointment record) — using it as an OLTP store would fight the tool's design and risk the availability NFR for exactly the workload it needs to protect
- ❌ No meaningful concept of row-level transactional locking the portal's write patterns need

**Option C — Purpose-fit split: Cloud SQL (OLTP) + Pub/Sub → Dataflow → BigQuery (streaming analytics), with Dataplex governance**
Transactional portal/account state in Cloud SQL with regional HA and read replicas; wearable telemetry ingested via the existing Pub/Sub → Dataflow → BigQuery pipeline; Dataplex for cataloging and PII policy tags across both.
- ✅ Each data shape runs on the system actually designed for it — this is the same "match platform to workload shape" reasoning as ADR-003's compute split, applied to data
- ✅ Directly reuses the already-validated streaming telemetry pipeline rather than redesigning ingestion from scratch
- ✅ Cloud SQL regional HA + automated backups gives a concrete, testable RPO — the Cloud SQL cross-region replica meets the ≤15 min RPO NFR directly (see ADR-007 for the full DR runbook)
- ❌ Three systems (Cloud SQL, Pub/Sub/Dataflow, BigQuery) instead of one — more moving parts, more IAM surface to manage per system

---

## Decision

**Option C** — purpose-fit split across Cloud SQL, the streaming pipeline, and BigQuery, governed by Dataplex.

The deciding factor is the same principle established in ADR-003: match the platform to the actual shape of the workload, rather than forcing one system to do everything adequately. Options A and B each pick a single system and accept a real mismatch for at least one workload — Option C is the only one where nothing is running on the wrong tool.

```
Wearable devices
      │
      ▼
  Pub/Sub (topic per region, respecting residency)
      │
      ▼
  Dataflow (streaming job — validated in the
  standalone telemetry pipeline project)
      │
      ├──────────────► BigQuery (partitioned/clustered,
      │                 column-level security on PII fields)
      │
      ▼
  Dataplex (catalog + policy tags — de-identification
  rules applied consistently across both stores below)

Clinic Portal / API
      │
      ▼
  Cloud SQL (Postgres, regional HA)
      │
      ├── Read replica (same region) — serves reporting
      │   queries the portal itself doesn't need to block on
      └── Cross-region replica — RPO/RTO target for DR (ADR-007)
```

**Residency enforcement:** BigQuery datasets and Cloud SQL instances are created per region-folder (from ADR-001), inheriting the same `gcp.resourceLocations` constraint — an EU telemetry dataset cannot physically be created in a US project, closing the same structural gap ADR-001 and ADR-002 closed for compute and network.

**PII/PHI handling:** Dataplex policy tags applied to telemetry fields (patient identifiers, precise location if present) enforce column-level access — a data analyst can query aggregate trends without ever seeing identifying fields, satisfying the least-privilege NFR at the column level, not just the dataset level.

**Absorbing traffic spikes:** Pub/Sub's own elasticity handles ingestion volume spikes natively — this is the direct answer to the "10x seasonal spike, no manual intervention" NFR for the highest-volume data path in the platform.

---

## Consequences

**Accepted trade-offs:**
- Three systems means three IAM surfaces and three monitoring configurations — mitigated by Dataplex providing one governance layer across BigQuery and (via policy tag propagation patterns) informing Cloud SQL's own column-level grants, rather than managing PII access rules independently in each system
- The read replica adds Cloud SQL cost even in low season — accepted because it's what keeps reporting-style queries off the primary instance the portal depends on for the availability NFR

**What this unlocks for later pillars:**
- ADR-005 (AI/ML): Vertex AI and the ADK agent query BigQuery directly, inheriting the same column-level PII protections already established here rather than needing a separate access model
- ADR-007 (Reliability/DR): the Cloud SQL cross-region replica is the literal mechanism the DR failover drill exercises

**Revisit if:** telemetry volume grows to the point where a single regional Dataflow job becomes a bottleneck — the pipeline was designed and load-tested independently in the standalone project; if MedSecure's projected volume exceeds what was validated there, revisit job parallelism before assuming the architecture itself needs to change.

---

## Implementation Status (updated after real build)

**Live**, with one open, explicitly tracked deviation: Cloud SQL currently runs on a temporary public IP + authorized-network configuration rather than the private-only design this ADR specifies, because the private-networking cutover is blocked by the VPC-SC perimeter (ADR-006) correctly refusing access to any caller not granted an explicit Access Level -- confirmed to block both local and HCP Terraform access identically. See known-deviations.md #1/#2/#14/#18. The real DR failover drill (ADR-007) was run against this live instance regardless, since the drill tests replication/promotion mechanics, not network topology.

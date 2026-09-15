# ADR-001: Landing Zone & Resource Hierarchy

**Status:** Accepted
**Pillar:** 1 — Landing Zone & Resource Hierarchy
**Date:** 2026-09-15

---

## Context

MedSecure needs a GCP resource hierarchy that enforces data residency (EU/US separation), supports independent prod/non-prod change velocity, and keeps IAM manageable as the number of services grows from ~5 (MVP) to 20+ (steady state). The hierarchy decision is foundational — it constrains every later network, security, and IAM design, so it's the first decision to lock in.

**Requirements this decision must satisfy:**
- Data residency: EU and US customer data must not cross region (NFR)
- HIPAA-aligned least privilege (NFR)
- Must scale to 20+ services without IAM sprawl becoming unmanageable

---

## Options considered

**Option A — Flat project structure, one project per environment (dev/staging/prod)**
All services in prod live in a single `medsecure-prod` project.
- ✅ Simple to set up, minimal folder overhead
- ❌ No structural boundary between EU and US data — residency would rely entirely on application-layer controls, not infrastructure
- ❌ IAM bindings at project level apply to *everything* in prod — violates least privilege for teams that only need access to one service

**Option B — Folder hierarchy by environment, then by region, then by service**
`Org → Folder (prod) → Folder (eu / us) → Project (per service)`
- ✅ Data residency enforced structurally: an org policy constraint (`constraints/gcp.resourceLocations`) can be scoped at the region folder level, making cross-region placement a policy violation, not just a convention
- ✅ IAM can be granted at the folder level for region-wide roles (e.g., an EU compliance auditor) and at the project level for service-specific roles — least privilege without excessive per-project duplication
- ❌ More folders to manage upfront; slightly more Terraform state to reason about

**Option C — Folder hierarchy by business unit only, region handled via labels**
`Org → Folder (per BU) → Project`, with `region: eu` / `region: us` as resource labels.
- ✅ Simpler structure if MedSecure ever adds unrelated business units
- ❌ Labels are *not* enforceable by org policy — residency would depend on every engineer applying labels correctly and every deploy pipeline checking them. This fails the "structural, not convention-based" enforcement bar the NFR requires.

---

## Decision

**Option B** — folder hierarchy by environment, then by region, then by service.

The deciding factor: only Option B lets data residency be enforced by an **org policy constraint** rather than a process or convention. For a HIPAA-aligned platform, "residency by convention" is not a defensible answer in a security review — it has to be structurally impossible to violate, not just discouraged.

```
Organization: medsecure.example
├── Folder: prod
│   ├── Folder: eu
│   │   ├── Project: medsecure-eu-api
│   │   ├── Project: medsecure-eu-data
│   │   └── Project: medsecure-eu-ml
│   └── Folder: us
│       ├── Project: medsecure-us-api
│       ├── Project: medsecure-us-data
│       └── Project: medsecure-us-ml
├── Folder: non-prod
│   ├── Folder: eu
│   └── Folder: us
└── Folder: shared-services
    ├── Project: medsecure-network-hub   (NCC hub, Shared VPC host)
    └── Project: medsecure-logging       (centralized audit logs)
```

**Org policy applied at each region folder:**
```
constraints/gcp.resourceLocations:
  in:eu-locations   # on the eu folder
  in:us-locations   # on the us folder
```

**IAM pattern:**
- Region-wide roles (compliance auditor, regional network admin) → granted at the region folder
- Service-specific roles (app developer, data engineer) → granted at the project level
- No IAM bindings at the `prod` folder level — this is intentional; it forces every grant to be scoped to a region at minimum

---

## Consequences

**Accepted trade-offs:**
- More Terraform modules/state to manage (one per folder + project) compared to a flat structure — mitigated by treating the landing zone as its own state-isolated module (see ADR-009, CI/CD)
- Cross-region shared services (network hub, logging) sit outside the eu/us split by design, which means they themselves need extra scrutiny — the hub project stores metadata and routing config only, never customer data, keeping it out of residency scope

**What this unlocks for later pillars:**
- ADR-002 (Network): Shared VPC host lives in `shared-services`, spoke VPCs live per-region-project — residency-safe by construction
- ADR-006 (Security): VPC Service Controls perimeters can be defined per region folder cleanly, since the folder boundary already matches the residency boundary

**Revisit if:** MedSecure expands beyond two regions (e.g., adds APAC) — the folder-per-region pattern scales, but the org policy constraint list needs updating per new region.

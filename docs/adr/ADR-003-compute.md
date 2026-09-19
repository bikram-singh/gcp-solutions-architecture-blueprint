# ADR-003: Compute & Modernization

**Status:** Accepted
**Pillar:** 3 — Compute & Modernization
**Date:** 2026-09-15

---

## Context

MedSecure's landing zone (ADR-001) and network (ADR-002) give every service project a residency-safe home and a way to reach the rest of the platform. Now those projects need actual compute: an API/backend tier serving the partner clinic portal, and event-driven services (webhook ingestion from wearable devices, notification dispatch) that don't need to run continuously.

MedSecure also isn't a greenfield build — it's replacing an existing on-prem monolith. The compute decision has to cover both **what runs the new platform** and **how the legacy system gets there**, since a migration plan without a concrete path is just aspiration.

**Requirements this decision must satisfy:**
- 99.95% availability for the API tier (NFR) — compute choice must support multi-zone/region resilience without heroics
- Absorb 10x seasonal traffic spikes without manual intervention (NFR) — autoscaling has to be real, not theoretical
- HIPAA-aligned least privilege (NFR) — workload identity, not long-lived service account keys, for anything touching PHI-adjacent data
- A credible migration path from the existing on-prem monolith — "rewrite everything from scratch" is not a defensible answer to a CFO or a security reviewer

---

## Options considered

**Option A — GKE Standard for everything**
Run both the API tier and event-driven services on a single GKE Standard cluster.
- ✅ One platform to operate, full control over node pools, network policy, and scheduling
- ❌ Event-driven workloads (webhook ingestion, notifications) are bursty and often idle — paying for always-on node capacity for infrequent triggers works against the "cost scales sub-linearly with users" NFR
- ❌ Node-level operations (OS patching, upgrades, node pool sizing) is exactly the DevOps-style toil this project is trying to move *away* from demonstrating — it doesn't showcase the "when do I choose managed over self-managed" judgment an SA role needs

**Option B — Cloud Run for everything**
Run both tiers as Cloud Run services.
- ✅ Fully managed, scales to zero, minimal operational surface
- ❌ The API tier has real statefulness needs (persistent connections, predictable latency for the clinician-facing portal) and benefits from finer control over scheduling, node-level networking policy, and workload placement that Cloud Run's fully-managed model doesn't expose — a mismatch documented explicitly here, not glossed over
- ❌ Doesn't showcase container orchestration judgment at all, which weakens the project as an SA portfolio piece — an all-serverless answer avoids the harder trade-off rather than resolving it

**Option C — GKE (Autopilot) for the stateful API tier, Cloud Run for event-driven services**
Split by workload shape: GKE Autopilot for the always-on, latency-sensitive API/backend; Cloud Run for webhook ingestion and notification dispatch.
- ✅ GKE Autopilot removes node-management toil (Google manages node provisioning/patching) while still giving pod-level scheduling control the API tier benefits from — Standard mode's extra node control isn't needed here since MedSecure has no unusual node-level customization requirement (no GPUs, no custom kernel modules)
- ✅ Cloud Run's scale-to-zero directly serves the "sub-linear cost scaling" NFR for genuinely bursty workloads
- ✅ Each workload type runs on the platform actually suited to its shape — the split *is* the architectural judgment, not a compromise
- ❌ Two compute platforms instead of one means two sets of operational patterns to document and monitor — accepted, since the alternative (Option A or B) means running the wrong tool for at least one workload type

---

## Decision

**Option C** — GKE Autopilot for the API/backend tier, Cloud Run for event-driven services.

The deciding factor: MedSecure's two workload types genuinely have different shapes (always-on/stateful vs. bursty/event-driven), and Option C is the only option that matches compute platform to workload shape rather than forcing one platform to cover both. That workload-shape reasoning — not "GKE is more powerful" or "serverless is simpler" — is the actual decision criterion, and it's the answer a reviewer should be able to reconstruct from this document alone.

**Autopilot over Standard specifically:** MedSecure has no requirement that needs Standard's extra node-level control (no GPUs, no privileged daemonsets, no custom node OS). Autopilot's per-pod billing and Google-managed node lifecycle removes real operational toil without giving anything up for this workload. Revisit if a future ML training workload (Pillar 5) needs GPU node pools Autopilot doesn't support well — that would justify a second, Standard-mode node pool for that specific use case only.

```
                    ┌─────────────────────────────┐
                    │   GKE Autopilot Cluster       │
                    │   (per region: eu / us)       │
                    │  ┌──────────┐  ┌───────────┐ │
                    │  │ API pods │  │ Backend   │ │
                    │  │ (HPA on  │  │ pods      │ │
                    │  │ custom   │  │           │ │
                    │  │ metric)  │  │           │ │
                    │  └──────────┘  └───────────┘ │
                    └───────────────────────────────┘

                    ┌───────────────────────────────┐
                    │   Cloud Run Services           │
                    │  ┌──────────────┐ ┌──────────┐│
                    │  │ Webhook       │ │Notification│
                    │  │ ingestion     │ │ dispatch  ││
                    │  │ (scale-to-0)  │ │(scale-to-0)││
                    │  └──────────────┘ └──────────┘│
                    └───────────────────────────────┘
```

**Autoscaling:** HPA on the GKE workloads tied to a custom Cloud Monitoring metric (request queue depth), not raw CPU — CPU-based scaling lags behind a genuine traffic spike; queue depth reacts before latency degrades, which is what "absorb 10x spikes without manual intervention" actually requires.

**Identity:** Workload Identity Federation for both GKE pods and Cloud Run services — no service account keys stored anywhere, matching the least-privilege NFR carried from ADR-001/002.

**Migration path (legacy monolith → this architecture), mapped to the 6 R's:**

| Component | 6 R's category | Rationale |
|---|---|---|
| Core API/backend logic | **Replatform** | Containerize as-is initially, move to GKE Autopilot; defer a full rewrite until the new platform is proven stable |
| Webhook/notification handlers | **Refactor** | These are new capabilities in the modernized platform, not lift-and-shift candidates — built natively for Cloud Run |
| Legacy batch reporting jobs | **Retire** | Superseded entirely by the BigQuery/Dataflow pipeline in Pillar 4 — no reason to migrate dead functionality |
| On-prem file storage for compliance archives | **Retain** (temporarily) | Regulatory retention requirements need legal sign-off before touching archived records — moved last, deliberately, not first |

---

## Consequences

**Accepted trade-offs:**
- Running two compute platforms (GKE + Cloud Run) means two monitoring/alerting patterns to maintain instead of one — mitigated in Pillar 10 (Observability) by using Cloud Monitoring's unified dashboarding across both rather than separate tooling per platform
- The Replatform-first approach for the core API means some legacy technical debt ships into the new platform initially — accepted explicitly, with the trade-off stated rather than hidden: stability now, refactor later, rather than a big-bang rewrite that risks the 99.95% availability target during cutover

**What this unlocks for later pillars:**
- ADR-005 (AI/ML): the ADK agent and Vertex AI workloads can reuse the same Workload Identity Federation pattern established here
- ADR-010 (Observability): golden-signals dashboards span both GKE and Cloud Run from day one, since both were designed with Cloud Monitoring integration in mind from this decision

**Revisit if:** a future workload needs GPU support or privileged node access that Autopilot doesn't accommodate — add a Standard-mode node pool scoped to that workload only, rather than migrating the whole cluster off Autopilot.

---

## Implementation Status (updated after real build)

**Live.** GKE Autopilot cluster (private nodes, per ADR-002) and both Cloud Run services applied to `medsecure-eu-api-prod`. Getting GKE working required six real, sequential fixes -- secondary IP ranges, `ip_allocation_policy`, Shared VPC IAM roles, GKE API on the host project, Shared VPC service-project attachment, and the org's `vmExternalIpAccess` policy -- all documented in known-deviations.md. Verified with a clean, zero-drift HCP Terraform apply.

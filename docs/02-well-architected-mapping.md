# MedSecure: Well-Architected Framework Mapping

Google Cloud's Well-Architected Framework defines six pillars for evaluating a cloud architecture. This document maps MedSecure's ten build pillars onto those six WAF pillars, so a reviewer familiar with the framework can quickly see where each concern is addressed — and, honestly, where each concern is only partially addressed given this project's real-world constraints.

---

## The six WAF pillars, and where MedSecure addresses each

### 1. Operational Excellence
*How well the system can be operated, monitored, and evolved.*

- **CI/CD (ADR-009):** git push → HCP Terraform plan → human-approval gate → apply, with a genuinely active GitHub Environment protection rule (verified via API, not just declared in YAML)
- **Observability (ADR-010):** golden-signals dashboards, a formal SLO with burn-rate alerting, organized by operational domain rather than by individual resource
- **Runbooks:** the DR failover runbook (`docs/dr-drill/failover-runbook.md`) is a real, drilled operational procedure, not just documentation

**Honest gap:** the CI/CD pipeline is proven for 7 of 9 modules; `landing-zone` and `data` are blocked on real external constraints (billing quota, VPC-SC access level) rather than fully operationally clean.

### 2. Security, Privacy & Compliance
*Protecting data, systems, and meeting regulatory obligations.*

- **Landing Zone (ADR-001):** residency enforced structurally via org policy, not convention
- **Security (ADR-006):** per-region VPC Service Controls perimeters (deliberately not one shared perimeter — see ADR-006's decision), CMEK on data stores, least-privilege IAM throughout
- **AI/ML (ADR-005):** the clinician agent's service account has exactly the same BigQuery access a human analyst would have — no elevated agent-specific permissions, containing the blast radius of any agent-scoping bug

**Honest gap:** Cloud SQL currently runs on a temporary public IP + authorized-network configuration rather than the fully private design, because the VPC-SC perimeter (working correctly) blocks the very Terraform runs that would complete the cutover — see `docs/known-deviations.md` items #1/#2/#14/#18. SCC Premium's BigQuery export was also deliberately left out of scope (requires a separate paid-tier activation).

### 3. Reliability
*The system's ability to recover from failure and meet its availability target.*

- **Reliability (ADR-007):** active-passive Cloud SQL with a real, measured, drilled failover — RTO ~3–4 min against a 60-min target, RPO 0 for the tested write
- **Network (ADR-002):** hub-and-spoke via NCC avoids the non-transitive routing trap that would otherwise limit scalable connectivity
- **Compute (ADR-003):** GKE Autopilot's managed node lifecycle removes a class of operational failure mode entirely

**Honest gap:** the original monitoring design for Reliability assumed Cloud SQL supported uptime checks directly — it doesn't. The module was redesigned around Cloud SQL's native `up` metric after discovering this against the live API, a genuine mid-build correction, not a design flaw that shipped uncorrected.

### 4. Performance Optimization
*Using resources efficiently to meet performance needs.*

- **Compute (ADR-003):** compute platform matched to workload shape — GKE Autopilot for the stateful API tier, Cloud Run for bursty event-driven work — rather than one platform forced to do both adequately
- **Data (ADR-004):** BigQuery for analytical queries, Cloud SQL for transactional — no single datastore asked to do both jobs well

**Honest gap:** load testing against the 10x seasonal-spike NFR was not performed — the autoscaling mechanisms exist and are architecturally sound, but their real behavior under genuine spike load is untested in this build.

### 5. Cost Optimization
*Achieving business goals at the lowest reasonable price point.*

- **Cost (ADR-008):** an explicit, itemized cost model separating fixed costs (DR replica, CMEK, SCC Premium — deliberately not hidden or minimized) from variable, usage-scaling costs, showing *why* the sub-linear NFR holds rather than just asserting it does
- A real bug was found and fixed in the cost module during the build: a hardcoded USD currency against an INR-denominated billing account, initially mis-diagnosed as a "platform limitation" before being correctly root-caused — see `docs/known-deviations.md` #10/#12/#23/#24

**Honest gap:** Committed Use Discounts are deliberately *not* provisioned via Terraform — a real financial commitment against invented forecast numbers would be a worse mistake than not having the discount at all. This is a considered scope boundary, not an oversight.

### 6. Sustainability
*Minimizing the environmental impact of cloud workloads.*

- Region selection (europe-west1, us-central1) follows Google's own lower-carbon-intensity region guidance, though this was not the primary driver of region choice (residency and latency were)
- GKE Autopilot's efficient node packing reduces idle-resource waste compared to a manually-sized Standard cluster

**Honest gap:** this pillar received the least dedicated design attention of the six — no explicit ADR addresses sustainability as its central decision driver. Worth naming plainly rather than retrofitting a sustainability narrative onto decisions that were actually made for other reasons.

---

## Mapping table: MedSecure's 10 pillars → WAF's 6 pillars

| MedSecure Pillar | Primary WAF Pillar(s) |
|---|---|
| 1. Landing Zone | Security, Operational Excellence |
| 2. Network | Reliability, Performance, Security |
| 3. Compute | Performance, Reliability, Sustainability |
| 4. Data | Performance, Reliability |
| 5. AI/ML | Security, Performance |
| 6. Security | Security & Compliance |
| 7. Reliability & DR | Reliability |
| 8. Cost | Cost Optimization |
| 9. CI/CD | Operational Excellence |
| 10. Observability | Operational Excellence, Reliability |

---

## Self-assessment scorecard

An honest, self-rated scorecard (1–5, 5 being strongest), per the original project's deliverables checklist — rated against real build outcomes, not design intentions:

| WAF Pillar | Self-rating | Why |
|---|---|---|
| Operational Excellence | 4/5 | CI/CD genuinely proven on 7/9 modules; real runbook drilled |
| Security, Privacy & Compliance | 4/5 | Strong design and mostly-live enforcement; one real, open gap (Cloud SQL private networking) |
| Reliability | 5/5 | The one pillar with a fully real, measured, successful drill |
| Performance Optimization | 3/5 | Sound design; genuinely untested under real load |
| Cost Optimization | 4/5 | Real bug found and fixed; deliberate, defensible scope boundary on CUDs |
| Sustainability | 2/5 | Present but not a driving design consideration |

This scorecard itself is worth including in the Medium article — an honest self-rating is a stronger credibility signal than an implied claim of doing everything perfectly.


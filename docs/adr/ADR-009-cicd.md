# ADR-009: CI/CD & Infrastructure as Code

**Status:** Accepted
**Pillar:** 9 — CI/CD & Infrastructure as Code
**Date:** 2026-09-15

---

## Context

Every prior pillar has produced a Terraform module (`landing-zone`, `network`, `compute`, `data`, `ai-ml`, `security`, `reliability`, `cost`), and this session's own build process — manually running `terraform init/validate/plan/apply` module by module, in dependency order, from a local machine — is exactly the pattern this pillar needs to formalize into a real pipeline. This reuses the existing HCP Terraform + GitHub Actions pipeline pattern (already built and proven on the FAST foundation project's 9-stage apply chain) rather than designing CI/CD from scratch.

**Requirements this decision must satisfy:**
- HIPAA-aligned least privilege (NFR) — pipeline credentials need scoped access per environment, not one broad credential that can touch everything
- The dependency order this session executed manually (`landing-zone` → `network` → `compute`/`data` → `ai-ml`/`security` → `reliability`/`cost`) needs to become an enforced, automated ordering — not something a human has to remember correctly every time

---

## Options considered

**Option A — A single GitHub Actions workflow that runs `terraform apply` on every module on every merge to main**
One workflow, no manual gate, no staged rollout.
- ✅ Simplest possible pipeline
- ❌ No human review between plan and apply for production changes — given this session's own experience with an accidental `terraform apply` destroying real resources, an unreviewed auto-apply to production is a materially higher-risk version of the exact mistake already made once. This session is direct, lived evidence for why this option is wrong, not just a theoretical concern
- ❌ No enforcement of module dependency order — a workflow that applies all 8 modules in parallel or in file-listing order risks the same kind of cross-module reference failures this build hit manually

**Option B — Fully manual apply, as this session did, with no pipeline at all**
Keep doing what was done throughout this build: local `terraform` commands, run by hand, module by module.
- ✅ Maximum control, no pipeline to build or maintain
- ❌ Doesn't scale past a single operator, and doesn't produce the audit trail (who ran what, when, with what plan output) that a HIPAA-aligned platform needs as a matter of course — this session's plan-output-committed-to-git approach is a reasonable *stopgap* for a capstone build, but isn't a real operational pattern for an ongoing platform

**Option C — HCP Terraform workspaces per module, with GitHub Actions running plan-on-PR (automatic) and apply gated behind manual approval for prod, extending the existing FAST foundation pipeline pattern**
One HCP Terraform workspace per module (matching this repo's existing `terraform/<module>/` structure), GitHub Actions triggers a plan on every PR touching that module's directory, and prod applies require a manual approval step; non-prod applies can be automatic.
- ✅ Directly reuses the FAST foundation project's proven 9-stage pipeline pattern rather than inventing a new one
- ✅ Manual approval gate for prod applies is the direct, structural fix for the exact incident this session had — an accidental destructive apply now requires a second, deliberate human action, not just one person's terminal
- ✅ Workspace-per-module with path-based triggers means a PR touching only `terraform/cost/` doesn't trigger a plan (let alone apply) against `terraform/landing-zone/` — enforcing the dependency isolation this session had to track manually
- ❌ More pipeline infrastructure to set up and maintain than Option A or B — accepted, since the alternative is either an automated destructive-apply risk (A) or an unscalable, unaudited manual process (B)

---

## Decision

**Option C** — HCP Terraform workspaces per module, GitHub Actions plan-on-PR, manual-approval-to-apply for prod.

The deciding factor is not hypothetical: this session's own incident (an accidental `terraform apply` destroying 14 real projects mid-troubleshooting) is direct evidence that a manual-only process (Option B) has a real failure mode, and that an unreviewed automated one (Option A) would make that failure mode worse, not better. A manual approval gate is the structural fix for precisely what went wrong.

```
PR opened, touching terraform/<module>/
      │
      ▼
GitHub Actions: path-filtered trigger
  (only the touched module's workspace runs — landing-zone
   and compute don't both plan just because compute changed)
      │
      ▼
HCP Terraform workspace: terraform plan
  (plan output posted as a PR comment automatically —
   the same "read the plan before touching anything"
   discipline this whole session's manual work followed)
      │
      ▼
   PR reviewed + merged
      │
      ▼
  ┌───────────────┴───────────────┐
  │                                 │
non-prod workspace              prod workspace
  auto-apply                     MANUAL APPROVAL
  (safe: non-prod                required before apply
   is disposable)                (the structural fix for
                                  this session's incident)
```

**Module dependency ordering**, matching what this session executed manually:
1. `landing-zone` (no dependencies)
2. `network` (depends on landing-zone's project IDs)
3. `compute`, `data` (depend on network's VPC/subnet self-links)
4. `ai-ml`, `security` (depend on data's datasets, compute's identities)
5. `reliability`, `cost` (depend on data's instance IDs, org-wide billing)

Enforced via HCP Terraform's `run triggers`, chaining each workspace to complete successfully before the next stage's workspace is eligible to plan — the automated version of the ordering this session tracked by memory and README status-table rows.

**Credentials:** each workspace uses its own scoped service account (Workload Identity Federation, no long-lived keys — same pattern as every compute/agent identity in this repo) with only the IAM roles that specific module's resources require, not one broad Terraform admin credential shared across all 8 modules.

---

## Consequences

**Accepted trade-offs:**
- 8 separate workspaces (one per module) is more HCP Terraform configuration than a single monolithic workspace — accepted because it's what enables path-filtered, dependency-ordered automation rather than an all-or-nothing apply
- The manual approval gate adds latency to prod changes — accepted explicitly as the direct cost of the safety this session's incident showed is necessary, not treated as pure friction to minimize away

**What this unlocks for later pillars:**
- ADR-010 (Observability): pipeline run history and plan/apply outcomes become their own monitored signal — a spike in failed applies is itself worth alerting on, feeding the same Cloud Monitoring approach as every other pillar

**Revisit if:** the 8-workspace-with-manual-ordering pattern becomes unwieldy as more modules are added — at that point, a proper orchestration layer (rather than chained run triggers) may be justified, but isn't yet, given the current module count.

---

## Implementation Status (updated after real build)

**Live and proven end-to-end.** All 9 HCP Terraform workspaces created, each wired to a dedicated Workload Identity Federation pool/provider and service account (scoped to MedSecure only, not reused from another project). 7 of 9 workspaces apply completely cleanly through the real pipeline (git push -> VCS trigger -> plan -> human approval -> apply); the other 2 are blocked on real, external, separately-documented constraints (billing quota, VPC-SC), not pipeline defects. The GitHub Environment `production` protection rule (required reviewer) is genuinely active, confirmed via the GitHub API -- this ADR's central safety mechanism, motivated by a real mid-session incident, is not just described in YAML but actually enforced.

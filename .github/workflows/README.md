# CI/CD Pipeline

Implements **ADR-009: CI/CD & Infrastructure as Code**.

## Workflows

- **`terraform-plan.yml`** — runs on every PR touching `terraform/**`. Detects which module(s) changed and plans only those, posting the result as a PR comment for review. No apply happens here.
- **`terraform-apply.yml`** — runs on merge to `main`. Non-prod applies automatically; prod applies require manual approval via a GitHub Environment protection rule named `production`.

## Setup required before these workflows are live

1. Create an HCP Terraform workspace per module (`landing-zone`, `network`, `compute`, `data`, `ai-ml`, `security`, `reliability`, `cost`) — 8 workspaces total, matching this repo's `terraform/<module>/` structure
2. Add `HCP_TERRAFORM_TOKEN` as a repo secret
3. In GitHub repo Settings → Environments, create an environment named `production` and add at least one required reviewer — **this is the actual safety mechanism**, not the workflow YAML alone. A workflow file referencing `environment: production` does nothing protective until that environment has a configured reviewer.
4. Each module's HCP Terraform workspace needs its own scoped Workload Identity Federation credential (per ADR-009) — do not reuse this project's earlier `terraform.tfvars`-based local-credential pattern for CI; that was appropriate for this session's manual, single-operator build, not for an automated pipeline with prod-apply authority.

## Why this exists — direct connection to this project's own incident

During this build, a `terraform apply` intended to fix a quota-project setting instead destroyed 14 real GCP projects, because the plan wasn't re-reviewed carefully enough before typing `yes` at the confirmation prompt. It was recovered cleanly via Terraform import blocks with zero data loss — but the incident is the direct, lived justification for `apply-prod`'s manual approval gate above. A pipeline is not meaningfully safer than a human running `terraform apply` locally unless something *structurally* forces a second, deliberate review before a destructive change reaches production. That's what the `environment: production` gate does, and it should never be removed to "speed up" deploys.

## Known limitation

These workflow files are written and reviewed but not yet wired to a live HCP Terraform organization or exercised end-to-end — the setup steps above are a prerequisite for that, not yet completed.

# Reliability Module

Implements the monitoring/alerting layer of **ADR-007: Reliability & Disaster Recovery**.

This module is intentionally small — the DR replica itself was already provisioned in `terraform/data` (ADR-004). What's built here is **only** Step 1 ("Detect") of the failover runbook at `docs/dr-drill/failover-runbook.md`:

- An uptime check against each region's primary Cloud SQL instance, checking every 5 minutes
- An alert policy that pages on-call only after **3 consecutive failures** (15 minutes) — matching the runbook's deliberate threshold to avoid false-positive failover on a transient blip
- The alert's documentation field links directly to the runbook, so whoever gets paged has the next step one click away, not buried in a wiki

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform validate
terraform plan -out=reliability.tfplan
```

## Design notes

- **Steps 2–6 of the runbook are deliberately not automated.** Promotion (`gcloud sql instances promote-replica`) is a one-way, non-reversible operation — see the runbook's rollback note. Automating that step entirely would remove the human judgment call ("is this a real outage or a false positive the alert missed?") that a well-designed DR process needs at exactly that decision point. This module automates detection; it does not automate the decision to fail over.
- **The failure threshold (3 consecutive, 15 min) is a variable, not hardcoded** — same reasoning as Cloud Armor's rate limit and Cloud Run's max-instances elsewhere in this repo: the "right" number depends on real operational data this project doesn't have yet. This is a reasoned starting point, not a tuned value.

## Known limitation

This module has not been applied, and **more importantly, the actual failover drill has not been run** — see the drill log in `docs/dr-drill/failover-runbook.md`, which is intentionally left blank pending real execution. Applying this module is a prerequisite for running that drill, not a substitute for it.

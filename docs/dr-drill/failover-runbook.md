# Failover Runbook: Cloud SQL Cross-Region DR

**Applies to:** `medsecure-eu-sql` → `medsecure-eu-sql-dr-replica`, and the identical `medsecure-us-sql` pairing (independent, never cross-region).
**RTO target:** ≤ 60 minutes | **RPO target:** ≤ 15 minutes

---

## Trigger conditions

Initiate this runbook when **any** of the following hold:
- Cloud Monitoring uptime check on the primary Cloud SQL instance fails for 3 consecutive checks (15 min at 5-min intervals)
- The on-call engineer independently confirms the primary is unreachable via `gcloud sql instances describe`
- A regional GCP outage is confirmed via the [Google Cloud Status Dashboard](https://status.cloud.google.com)

Do **not** initiate failover on a single alert — false positives from transient network blips are more disruptive than the outage itself. Three consecutive failures is the deliberate threshold.

## Steps

**1. Detect** — Cloud Monitoring alert fires, pages on-call via the configured notification channel.

**2. Declare** — On-call confirms the primary is genuinely down (not a monitoring false positive), declares an incident, and **starts the clock**. Timestamp this — it's the anchor for the RTO measurement.

**3. Promote the replica**
```bash
gcloud sql instances promote-replica medsecure-eu-sql-dr-replica \
  --project=medsecure-eu-data-prod
```
This is a one-way, non-reversible operation — the replica becomes an independent primary. Do not run this speculatively; only after Step 2's declaration.

**4. Re-point application connections**
Run the documented cutover script (`scripts/dr-repoint.sh`), which updates the Cloud Run/GKE environment configuration to point at the promoted instance's connection string. This is scripted deliberately — manually editing connection strings under incident pressure is a common source of extended outages.

**5. Verify**
Run the smoke-test query set (`scripts/dr-smoke-test.sql`) against the promoted instance: confirm schema integrity, confirm the most recent transaction timestamp (this is your actual measured RPO — the gap between this timestamp and the incident start time), confirm the application tier can connect and serve a request end-to-end.

**6. Confirm and record**
Mark the incident resolved. Record the actual elapsed time (RTO) and the actual data-loss window (RPO) in the drill log below. Notify stakeholders.

## Rollback note

Promotion is one-way. Returning to the original region requires standing up a *new* replica from the promoted instance and repeating this process in reverse — there is no "undo" for step 3. This is a deliberate, known limitation of the active-passive design (ADR-007) and should be communicated to stakeholders as part of any real incident, not discovered during one.

---

## Drill log

| Date | Trigger (drill/real) | Declared at | Promoted at | Verified at | Measured RTO | Measured RPO | Notes |
|---|---|---|---|---|---|---|---|
| _pending_ | Drill | — | — | — | — | — | **Not yet executed.** This runbook has been written and reviewed but not drilled against live infrastructure. The `terraform/data` module's Cloud SQL instances (ADR-004) have not yet been applied to the sandbox org — see that module's known-limitations note. A drill requires those instances to exist first. Scheduled as the next concrete step once the data module is applied. |

**This blank drill log is deliberate, not an oversight.** The repo's credibility depends on this table containing real, measured numbers from an actual promotion — not fabricated ones. Filling this in with invented timings would be a worse outcome for the portfolio than an honest "not yet executed, here's exactly what's blocking it and what happens next."

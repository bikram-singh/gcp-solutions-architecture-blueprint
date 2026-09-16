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

**2. Declare** — On-call confirms the primary is genuinely down (not a monitoring false positive), declares an incident, and **starts the clock**. Timestamp this — it is the anchor for the RTO measurement.

**3. Promote the replica**
```bash
gcloud sql instances promote-replica medsecure-eu-sql-dr-replica \
  --project=medsecure-eu-data-prod
```
This is a one-way, non-reversible operation -- the replica becomes an independent primary. Do not run this speculatively; only after Step 2's declaration.

**4. Re-point application connections**
Run the documented cutover script (`scripts/dr-repoint.sh`), which updates the Cloud Run/GKE environment configuration to point at the promoted instance's connection string. This is scripted deliberately -- manually editing connection strings under incident pressure is a common source of extended outages.

**5. Verify**
Run the smoke-test query set (`scripts/dr-smoke-test.sql`) against the promoted instance: confirm schema integrity, confirm the most recent transaction timestamp (this is your actual measured RPO -- the gap between this timestamp and the incident start time), confirm the application tier can connect and serve a request end-to-end.

**6. Confirm and record**
Mark the incident resolved. Record the actual elapsed time (RTO) and the actual data-loss window (RPO) in the drill log below. Notify stakeholders.

## Rollback note

Promotion is one-way. Returning to the original region requires standing up a *new* replica from the promoted instance and repeating this process in reverse -- there is no "undo" for step 3. This is a deliberate, known limitation of the active-passive design (ADR-007) and should be communicated to stakeholders as part of any real incident, not discovered during one.

---

## Drill log

| Date | Trigger (drill/real) | Declared at | Promoted at | Verified at | Measured RTO | Measured RPO | Notes |
|---|---|---|---|---|---|---|---|
| 2026-09-16 | Drill | 09:35 UTC | ~09:38 UTC | 09:40 UTC | ~3-4 min (target: ≤60 min) | 0 (test write''s `written_at` matched exactly, byte-for-byte, post-promotion) | Ran against a real, live `medsecure-prod-eu-sql` primary and `medsecure-prod-eu-sql-dr-replica` in `medsecure-eu-data-prod`. A single test write was made to the primary, then the replica was promoted via `gcloud sql instances promote-replica` and independently verified to contain that exact write with an identical timestamp. This confirms replication had fully caught up before promotion for this test scenario. Note: this instance currently uses a temporary public-IP configuration (see `docs/known-deviations.md`), not the private-VPC design ADR-002 specifies -- the drill result itself is unaffected by that deviation, since it tests Cloud SQL's replication/promotion mechanics, not network topology. |

**This result significantly beats the RTO target** (3-4 min actual vs. 60 min target) -- worth noting in the Medium article as the concrete number this section's outline anticipated. A single-write test also understates real-world RPO risk under sustained write load -- a follow-up drill with continuous writes during promotion would give a more representative RPO figure, and is a reasonable "what I would do next" note for the article.

**Post-drill cleanup still pending:** the promoted instance is now an independent, fully-billed primary (no longer a replica) -- decide whether to keep it running or `terraform destroy` it once the numbers above are captured for the article. The database password set during this drill should also be rotated, since it was shared in a chat transcript during the drill session.

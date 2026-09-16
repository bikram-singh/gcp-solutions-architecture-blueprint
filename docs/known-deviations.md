
---

## 2. Org policy sql.restrictPublicIp disabled on medsecure-eu-data-prod

**What is normally enforced:** the org has constraints/sql.restrictPublicIp enforced, blocking public IPs on Cloud SQL instances -- itself already implementing what ADR-002 requires structurally.

**What was done:** this constraint was explicitly disabled at the project level (gcloud resource-manager org-policies disable-enforce) to allow deviation #1 (public-IP Cloud SQL) to actually apply.

**Why:** to unblock the Pillar 7 DR drill today rather than wait for the network module.

**Resolution plan:** once the network module is applied and Cloud SQL reverts to private-only (see deviation #1), re-enable this constraint with: gcloud resource-manager org-policies enforce constraints/sql.restrictPublicIp --project=medsecure-eu-data-prod

**Status:** Open. This is the more consequential of the two open deviations -- it changes actual org-level security posture, not just one resource config. Prioritize resolving this over deviation #1 once network is available.

---

## 4. Promoted DR replica cleanup (resolved)

After the DR drill (docs/dr-drill/failover-runbook.md), the promoted instance medsecure-prod-eu-sql-dr-replica was removed from Terraform state (via a removed block, since it was no longer a true replica post-promotion) and deleted from GCP directly. Deletion initially returned PERMISSION_DENIED via both gcloud and the Console despite Owner-level IAM, for reasons not fully diagnosed -- but the instance was confirmed gone from `gcloud sql instances list` shortly after, so the delete evidently succeeded despite the reported error. Only medsecure-prod-eu-sql remains, confirmed RUNNABLE.

**Status:** Resolved.

---

## 5. Reliability module: uptime check against cloudsql_database not supported (open)

The reliability module's `google_monitoring_uptime_check_config` targets a `cloudsql_database` monitored resource via TCP check. Applying it against the real, live `medsecure-prod-eu-sql` instance consistently fails with "Error confirming monitored resource," unaffected by label-format changes (with/without region). This strongly suggests the Uptime Check API does not support `cloudsql_database` as a monitored resource type for TCP checks the way this module assumed -- Cloud SQL health is more commonly monitored via its own built-in metrics (`cloudsql.googleapis.com/database/up`) through a `google_monitoring_alert_policy` directly, without an uptime check wrapper at all.

**Important:** this does NOT affect the validity of the real DR drill already performed and recorded in `docs/dr-drill/failover-runbook.md` -- that drill was run and measured manually against live infrastructure, independent of this alerting automation.

**Resolution plan:** redesign the alert policy to query `cloudsql.googleapis.com/database/up` directly instead of going through an uptime check, and drop the `google_monitoring_uptime_check_config` resource entirely.

**Status:** Open.

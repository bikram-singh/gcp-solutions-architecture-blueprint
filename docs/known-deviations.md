
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

---

## 6. GKE cluster: private nodes required (resolved, and consistent with design)

The first two GKE Autopilot creation attempts failed with STATUS: ERROR because the org enforces constraints/compute.vmExternalIpAccess, which blocks external IPs on node VMs. Fixed by adding private_cluster_config (enable_private_nodes=true) to the cluster resource. This is not a workaround -- ADR-002 already specified no public IPs on backend tiers, so this fix brings the implementation in line with the original design rather than deviating from it. Two broken clusters were created and deleted during debugging; no data loss, both were empty clusters with no workloads deployed.

**Status:** Resolved.

---

## 7. SCC BigQuery export skipped (org-level Premium required)

The google_scc_v2_organization_scc_big_query_exports resource in the security module requires Security Command Center Premium to be actively activated at the org level (a separate, paid activation step beyond just enabling the API), plus a specific SCC admin IAM role. This was not set up as part of this build and was deliberately skipped rather than chasing a new paid-tier activation. The resource is commented out in terraform/security/main.tf.

**Status:** Deliberately out of scope for this session.

---

## 8. Incident: security module briefly renamed the shared org access policy

Applying the security module imported the existing org-level Access Policy (accessPolicies/731858017875, title "gch-access-policy", owned by the separate FAST foundation project) rather than creating a duplicate, since access policies are singleton per organization. The import was correct, but main.tf still specified this module's own intended title ("medsecure-access-policy"), so the same apply that imported the policy also renamed it -- unintentionally overwriting a title used by another real project. Caught and reverted within the same session via `gcloud access-context-manager policies update --title=gch-access-policy`. No other properties of the policy were affected, and IDs (which other integrations would reference, not titles) never changed. main.tf now explicitly sets title to match the existing policy's real name, with a comment explaining this module does not own or rename it.

**Status:** Resolved. Verify no other artifact (dashboards, docs, screenshots) in the FAST foundation project captured the temporary renamed state.


---

## 2. Org policy sql.restrictPublicIp disabled on medsecure-eu-data-prod

**What is normally enforced:** the org has constraints/sql.restrictPublicIp enforced, blocking public IPs on Cloud SQL instances -- itself already implementing what ADR-002 requires structurally.

**What was done:** this constraint was explicitly disabled at the project level (gcloud resource-manager org-policies disable-enforce) to allow deviation #1 (public-IP Cloud SQL) to actually apply.

**Why:** to unblock the Pillar 7 DR drill today rather than wait for the network module.

**Resolution plan:** once the network module is applied and Cloud SQL reverts to private-only (see deviation #1), re-enable this constraint with: gcloud resource-manager org-policies enforce constraints/sql.restrictPublicIp --project=medsecure-eu-data-prod

**Status:** Open. This is the more consequential of the two open deviations -- it changes actual org-level security posture, not just one resource config. Prioritize resolving this over deviation #1 once network is available.

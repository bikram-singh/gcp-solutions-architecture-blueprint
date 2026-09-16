#!/usr/bin/env bash
# dr-repoint.sh
# Step 4 of docs/dr-drill/failover-runbook.md.
#
# Re-points the application tier's Cloud SQL connection at the promoted
# DR replica. Scripted deliberately -- manual connection-string edits
# under incident pressure are a common source of extended outages.
#
# STATUS: stub. This script documents the intended mechanism (update
# the Cloud Run / GKE environment's DB connection env var, then trigger
# a rolling restart) but has not been implemented against a live
# deployment yet, since the compute and data modules (ADR-003, ADR-004)
# have not been applied to the sandbox org. Do not treat this as
# production-ready until it has been exercised in a real drill.

set -euo pipefail

REGION="${1:?Usage: dr-repoint.sh <region: eu|us>}"
PROMOTED_INSTANCE="medsecure-${REGION}-sql-dr-replica"

echo "Re-pointing MedSecure ${REGION} application tier to ${PROMOTED_INSTANCE}..."

# Intended implementation (not yet live):
# 1. Fetch the promoted instance's connection name:
#    gcloud sql instances describe "${PROMOTED_INSTANCE}" \
#      --project="medsecure-${REGION}-data-prod" \
#      --format="value(connectionName)"
#
# 2. Update the Cloud Run service's env var:
#    gcloud run services update "medsecure-${REGION}-api" \
#      --project="medsecure-${REGION}-api-prod" \
#      --update-env-vars="DB_CONNECTION_NAME=<connection-name-from-step-1>"
#
# 3. Confirm the rolling restart completes and new revisions are serving:
#    gcloud run services describe "medsecure-${REGION}-api" \
#      --project="medsecure-${REGION}-api-prod" \
#      --format="value(status.latestReadyRevisionName)"

echo "STUB: implement against live compute/data modules before first real drill."
exit 1

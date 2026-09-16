# AI/ML Module

Implements **ADR-005: AI/ML Layer**.

Builds:
- A **dedicated service account per region** for the ADK clinician agent, granted only `bigquery.dataViewer` + `bigquery.jobUser` — the same access a human clinical analyst would have, deliberately not broader
- The **ADK agent itself**, deployed as a Cloud Run service per region, reusing the existing agent design (Python/Google ADK, Gemini 2.5 Flash on Vertex AI) extended with BigQuery grounding
- A **Vertex AI endpoint per region** for the anomaly detection model (Model Garden, pre-trained — not custom-trained, per ADR-005's decision)

## Usage

Depends on `landing-zone` (project IDs) and `data` (BigQuery datasets the agent grounds against).

```bash
cp terraform.tfvars.example terraform.tfvars
# set agent_container_image to your actual built image
terraform init
terraform validate
terraform plan -out=ai-ml.tfplan
```

## Design notes (why the code looks like this)

- **The IAM grants are the load-bearing security control in this module.** `roles/bigquery.dataViewer` + `roles/bigquery.jobUser` — not `bigquery.admin`, not a custom broader role — is the direct implementation of ADR-005's core decision: the agent can leak at most what a compromised analyst credential could leak, never more. If you're reviewing this module for a security-focused audience, start here, not with the Cloud Run config.
- **One agent instance per region, not one global agent.** Same residency pattern as every prior pillar — an EU agent instance only has BigQuery access scoped to the EU project, so there's no code path where an EU clinician's query could retrieve US patient data.
- **The Vertex AI Model Garden deployment step is intentionally NOT in this Terraform.** At the time of writing, deploying a Model Garden model to an endpoint isn't fully declarative in the `google` provider — this module provisions the endpoint infrastructure; the model deployment itself is a `gcloud ai models deploy` step run separately. This is noted explicitly rather than faked with a resource that doesn't actually do what it looks like it does.
- **`agent_min_instances = 0` by default** — same scale-to-zero reasoning as the compute module's event-driven services (ADR-003): clinician query volume outside clinic hours is genuinely zero, so there's no reason to pay for idle capacity.

## Known limitation

Not yet run against a live org — same caveat as every prior module. Additionally: this module assumes `agent_container_image` points to a real, already-built image extending the existing terraform-adk-agent project with BigQuery grounding logic — that extension work is application code, not infrastructure, and isn't part of this Terraform module.

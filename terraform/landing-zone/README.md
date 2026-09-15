# Landing Zone Module

Implements **ADR-001: Landing Zone & Resource Hierarchy**.

Builds:
- `prod` / `non-prod` folders under the org
- `eu` / `us` region folders nested under each environment folder
- `gcp.resourceLocations` org policy on each region folder, enforcing data residency structurally
- A `shared-services` folder (network hub, centralized logging) outside the eu/us split
- Service projects (`api`, `data`, `ml`) under every environment/region combination

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars with your real org_id and billing_account

terraform init
terraform validate
terraform plan -out=landing-zone.tfplan
```

Commit the `terraform plan` output (redact the org ID / billing account if the repo is public) alongside this module as your proof-of-apply artifact, per the repo's deliverables checklist.

## Prerequisites

- Terraform >= 1.7
- `google` provider `~> 5.0`
- Credentials with `roles/resourcemanager.folderAdmin`, `roles/resourcemanager.projectCreator`, and `roles/orgpolicy.policyAdmin` at the org level
- An existing GCP Organization and billing account

## Design notes (why the code looks like this)

- **`google_org_policy_policy` is applied per region folder, not per project.** This is the core decision from ADR-001 — residency is enforced at the folder boundary, so no project created under `eu` can ever be placed outside EU-allowed locations, regardless of what an individual engineer configures later.
- **`setproduct()` generates the environment × region × service matrix** rather than hand-listing every project. This keeps the module scaling cleanly if a third region (e.g. `apac`) is added later — update `var.regions` and the folder/project set grows automatically, exactly the "revisit if" condition called out in ADR-001.
- **Shared services are a separate top-level folder**, deliberately outside the environment/region tree, because the network hub and logging projects hold routing/metadata only — never customer data — so they're out of residency scope by design, not by exception.

## Known limitation / what to verify before applying

This module was authored and validated for correct HCL syntax and resource graph structure, but **has not been run against a live GCP organization** — running `terraform plan` requires real org-level credentials and a target org, which this project doesn't have access to. Before you apply:

1. Run `terraform validate` locally to confirm syntax
2. Run `terraform plan` against a **sandbox/test org first**, not directly against a production org — the plan output will show exactly how many folders/projects/policies it intends to create
3. Double-check the `google_org_policy_policy` resource against the current provider version's schema — Google's org policy API has changed shape across provider versions, so pin `~> 5.0` and confirm against the [provider docs](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/org_policy_policy) if you're on a different version

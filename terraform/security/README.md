# Security Module

Implements **ADR-006: Security & Compliance**.

Builds:
- One **org-level VPC-SC access policy** plus **one perimeter per region** — extending the existing VPC-SC lab's design, deliberately not a single global perimeter
- **Cloud KMS key ring + CMEK key per region**, 90-day rotation, `prevent_destroy` set (a destroyed CMEK key permanently orphans any data encrypted with it — this is not a resource to ever `terraform destroy` casually)
- **Security Command Center Premium** findings export to BigQuery, feeding the same centralized logging project from ADR-001

## Usage

Depends heavily on `landing-zone`'s outputs — this is the module with the most cross-module wiring so far.

```bash
cp terraform.tfvars.example terraform.tfvars
# Fill org_id and PROJECT NUMBERS (not IDs) for each perimeter --
# get these with: gcloud projects describe <project-id> --format="value(projectNumber)"
# for each of the 6 production service projects.

terraform init
terraform validate
terraform plan -out=security.tfplan
```

## Design notes (why the code looks like this)

- **Two perimeters, never one.** This is the literal implementation of ADR-006's core decision — the `for_each` over `var.perimeters` creates independent perimeter resources with no bridge rule between them. If a future need for cross-region data flow arises, that requires a new, explicit `google_access_context_manager_service_perimeter_egress_policy` (or a perimeter bridge) added deliberately — not a loosening of either perimeter's own boundary.
- **VPC-SC needs project *numbers*, not project IDs**, unlike almost every other resource in this repo's Terraform. This is a genuine, easy-to-miss API quirk — the `terraform.tfvars.example` calls this out explicitly so it doesn't cost you a confusing error later.
- **`prevent_destroy = true` on the CMEK key** is not boilerplate caution — it's the single most consequential safety flag in this whole repo. Destroying a CMEK key doesn't just delete a Terraform resource; it makes every byte of data encrypted with that key permanently unrecoverable. Given this session's earlier incident with an accidental `terraform apply` destroy, this flag exists specifically to make that class of mistake structurally impossible for this resource.
- **The KMS key ring's project is the region's first data project**, not a dedicated security project — a deliberate simplification for this capstone's scope. In a larger real deployment, a dedicated `medsecure-<region>-kms` project would be cleaner, but for MedSecure's footprint this keeps the module count from growing without a corresponding real benefit.

## Known limitation

Not yet run against a live org, and this module in particular has more manual cross-module value-wiring than any prior one (project numbers specifically, not just IDs) — expect to spend real time on `terraform.tfvars` before a meaningful `plan` is possible here.

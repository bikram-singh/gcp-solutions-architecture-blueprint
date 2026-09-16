# Cost Module

Implements the alerting layer of **ADR-008: Cost Optimization / FinOps**.

Builds:
- An **org-wide budget** with alert thresholds at 50/80/100/120% of the monthly target
- A **notification channel** for the monthly FinOps review cadence described in ADR-008

The full cost model (cost-per-1,000-users, itemized by ADR) lives in `cost-model/cost-model.csv` at the repo root, not in this module — that's a planning artifact, not infrastructure.

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform validate
terraform plan -out=cost.tfplan
```

## What this module deliberately does NOT do

**Committed Use Discounts are not provisioned here.** CUDs are a financial commitment against forecast usage, typically 1-3 years — purchasing them via Terraform against made-up numbers would be worse than not having them at all, since a wrong commitment is a real, binding cost mistake, not a reversible config error. CUD purchase is intentionally left as a manual, reviewed decision made once real usage data exists (see ADR-008's "revisit if" clause) — this module only builds the *visibility* (budget alerts) that would inform that future decision, not the commitment itself.

## Design notes

- **`monthly_budget_amount_usd` defaults to $2,000`**, taken directly from the illustrative cost model's 1,000-user total (~$1,385) with headroom — this is explicitly a starting estimate, not a validated figure, and the module variable makes that easy to revise once real billing data exists.
- **The budget filter is org-wide (`projects = []`)** rather than scoped to a subset — at MedSecure's current size, a single org-wide view is more useful than per-project budgets that would just fragment the monthly review. Revisit if the org grows enough that per-project budgets become more actionable than one aggregate view.

## Known limitation

Not yet applied. Depends on `landing-zone`'s `medsecure-logging` project existing first (for the notification channel).

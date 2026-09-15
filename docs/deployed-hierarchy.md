# Deployed Resource Hierarchy

This is the real, applied hierarchy under the GCP Organization used to build and validate this project — not a diagram of intent, but a record of what actually exists as of the landing-zone module's apply.

Org and folder IDs below are redacted (`<ORG_ID>`, `<FOLDER_ID>`) since this repo is public; project IDs are shown as-is since they carry no sensitive information on their own.

```
Organization: <ORG_ID>
│
├── Folder: gch-IT (<FOLDER_ID>)                 ← NOT part of MedSecure — a separate landing-zone project
│   └── Folder: Prod
│       └── Project: gch-net-host                ← separate project, untouched by this repo's Terraform
│
├── Project: gcphub-dev                           ← separate project, untouched
├── Project: gcphub-prod                          ← separate project, untouched
├── Project: project-cloud-armor                  ← separate project, untouched
├── Project: project-streaming-telemetry          ← separate project; MedSecure's data pillar (ADR-004)
│                                                     reuses this pipeline's design, not this project itself
│
├── Folder: non-prod (<FOLDER_ID>)                ← MedSecure, created by terraform/landing-zone
│   ├── Folder: eu (<FOLDER_ID>)
│   │   ├── Project: medsecure-eu-api-non-prod
│   │   ├── Project: medsecure-eu-data-non-prod
│   │   └── Project: medsecure-eu-ml-non-prod
│   └── Folder: us (<FOLDER_ID>)
│       ├── Project: medsecure-us-api-non-prod
│       ├── Project: medsecure-us-data-non-prod
│       └── Project: medsecure-us-ml-non-prod
│
├── Folder: prod (<FOLDER_ID>)                    ← MedSecure, created by terraform/landing-zone
│   ├── Folder: eu (<FOLDER_ID>)
│   │   ├── Project: medsecure-eu-api-prod
│   │   ├── Project: medsecure-eu-data-prod
│   │   └── Project: medsecure-eu-ml-prod
│   └── Folder: us (<FOLDER_ID>)
│       ├── Project: medsecure-us-api-prod
│       ├── Project: medsecure-us-data-prod
│       └── Project: medsecure-us-ml-prod
│
└── Folder: shared-services (<FOLDER_ID>)         ← MedSecure, created by terraform/landing-zone
    ├── Project: medsecure-logging
    └── Project: medsecure-network-hub
```

This matches ADR-001's design exactly: environment folder → region folder → service project, with shared services kept outside the eu/us split.

## Provenance note

Every project and folder under `non-prod`, `prod`, and `shared-services` above was created by `terraform apply` against this repo's `terraform/landing-zone` module, run against a live GCP Organization — not simulated, not plan-only. See `terraform/landing-zone/landing-zone-plan-output.txt` for the original verified plan, and the module's README for the full apply history, including a mid-apply incident (accidental resource taint/destroy during a billing-quota troubleshooting session) that was recovered via Terraform import blocks with zero data loss and zero resources ultimately destroyed.

# ADR-005: AI/ML Layer

**Status:** Accepted
**Pillar:** 5 — AI/ML Layer
**Date:** 2026-09-15

---

## Context

MedSecure's data pillar (ADR-004) gives clinicians a BigQuery analytics warehouse of wearable telemetry, but raw SQL access isn't how a clinician wants to work — they want to ask "has this patient's resting heart rate trended up over the last month?" in plain language, and they want the platform to flag anomalies before they have to go looking. That's two distinct AI/ML needs: a **predictive/anomaly-detection model** running continuously against the telemetry stream, and a **conversational agent** clinicians query directly.

This pillar reuses the existing ADK-based agent (Python + Google ADK on Gemini 2.5 Flash via Vertex AI) already built and working — the ADR treats that agent's core design as proven, and focuses on how it integrates into MedSecure and what changes for a healthcare-specific, multi-region deployment.

**Requirements this decision must satisfy:**
- HIPAA-aligned least privilege + audit logging (NFR) — an agent answering questions about patient data needs the same column-level PII discipline as ADR-004 established, not a separate, looser access model
- EU/US data residency (NFR) — a model or agent must never be grounded on data that crosses the residency boundary
- Absorb 10x seasonal traffic spikes (NFR) — clinician query volume during flu season is exactly when anomaly detection matters most, so the AI layer can't degrade under load
- The agent must be genuinely useful, not a demo — grounded, accurate answers a clinician can trust with a patient in front of them

---

## Options considered

**Option A — Fine-tune a custom model on MedSecure's telemetry data**
Train a bespoke model instead of using a foundation model with grounding.
- ✅ Potentially higher accuracy on the specific telemetry patterns MedSecure sees
- ❌ Requires a labeled training dataset MedSecure doesn't have yet (no real patient history at this stage of the build) — training on synthetic data risks a model tuned to patterns that don't reflect real clinical presentations
- ❌ Retraining/maintenance burden is high for a capstone project scope, and doesn't showcase the RAG/grounding architecture pattern that's more broadly applicable across SA scenarios

**Option B — General-purpose chatbot with no grounding, answering from model knowledge alone**
Deploy Gemini directly, no connection to BigQuery.
- ✅ Fastest to stand up, no data pipeline integration needed
- ❌ Cannot answer any question about an actual patient's actual data — the model would either refuse or, worse, hallucinate plausible-sounding numbers, which is a serious risk in a healthcare context and directly undermines the "clinician must trust it" requirement
- ❌ Fails the core use case entirely — this isn't a real option so much as a baseline to reject explicitly

**Option C — Vertex AI anomaly detection model + ADK agent grounded on BigQuery via RAG, reusing the existing agent design**
Vertex AI Model Garden model (not custom-trained) for anomaly detection on telemetry; the existing ADK agent, extended to query BigQuery directly and ground its answers in real data.
- ✅ Grounding solves Option B's hallucination risk — every answer traces back to an actual BigQuery query result, not model memory
- ✅ Reuses validated agent architecture rather than rebuilding — same reasoning as ADR-004's pipeline reuse
- ✅ Model Garden avoids Option A's training-data problem — a pre-trained anomaly detection model can be evaluated against telemetry patterns without needing MedSecure-specific training data first
- ❌ Grounding quality depends on how well the agent's retrieval step is scoped — a badly-scoped query could pull data outside what the clinician should see, which becomes the specific design problem this ADR has to solve (see below)

---

## Decision

**Option C** — Vertex AI Model Garden anomaly detection + the existing ADK agent, extended with BigQuery grounding.

The deciding factor: grounding is what makes an AI answer trustworthy enough for a clinical context, and reusing the proven agent design means the engineering risk is concentrated in the one genuinely new piece — the grounding/retrieval scoping — rather than spread across a rebuilt agent and an unproven training pipeline simultaneously.

```
Clinician query ("Has patient X's resting HR trended up?")
      │
      ▼
  ADK Agent (Gemini 2.5 Flash, Vertex AI)
      │
      ├── Retrieval step: scoped BigQuery query
      │   (same column-level PII policy tags from ADR-004 —
      │    the agent's service account has the SAME
      │    least-privilege grants a human analyst would have,
      │    not elevated access)
      │
      ▼
  Grounded response, citing the actual queried values


Telemetry stream (from ADR-004's Pub/Sub -> Dataflow -> BigQuery)
      │
      ▼
  Vertex AI Model Garden anomaly detection model
      │
      ▼
  Flagged anomalies -> written back to BigQuery as an
  annotated table the agent can also query
```

**The specific design decision that makes this safe:** the agent's Workload Identity Federation service account (same pattern as ADR-003's compute identities) is granted the **same column-level BigQuery access a human clinical analyst would have** — it does not get elevated or agent-specific permissions. This means a scoping bug in the agent's retrieval logic can leak at most what a compromised analyst credential could leak, not more. That containment property is the actual answer to "how do you keep a grounded agent from becoming a PII exfiltration vector," which is the sharper version of Option C's stated weakness above.

**Residency:** per ADR-004, BigQuery datasets are region-scoped. The agent is deployed once per region (EU agent instance, US agent instance), each grounded only against its own region's dataset — an EU clinician's query never retrieves US patient data, structurally, not by convention.

**Absorbing traffic:** Vertex AI's managed serving scales with query volume; the anomaly detection model runs as a scheduled/triggered batch job against the streaming pipeline rather than per-query, so clinician query spikes and telemetry-volume spikes don't compete for the same compute.

---

## Consequences

**Accepted trade-offs:**
- Model Garden's pre-trained anomaly model is a starting point, not a MedSecure-tuned model — accepted, since Option A's alternative (train from scratch on absent data) is worse, not better; this is revisited once real usage data exists
- Running two regional agent instances instead of one global one adds deployment surface — accepted, since it's the direct mechanism that keeps residency enforcement structural rather than convention-based, consistent with every prior pillar's approach to the same NFR

**What this unlocks for later pillars:**
- ADR-010 (Observability): agent query logs and anomaly-detection outputs feed the same Cloud Monitoring dashboards as the rest of the platform, not a separate AI-specific observability stack
- ADR-006 (Security): the "same access as a human analyst" principle here is a direct instance of the least-privilege pattern ADR-006 formalizes platform-wide

**Revisit if:** clinician usage reveals grounding gaps (the agent can't answer a class of question a human analyst could) — at that point, either the retrieval query patterns need expanding within the same access boundary, or a genuinely MedSecure-tuned model becomes justified once real usage data exists to train on.

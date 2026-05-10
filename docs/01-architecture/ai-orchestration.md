# AI Orchestration

## Purpose

How model calls are routed, how tools are abstracted, and — most importantly — when family data is allowed to leave owned infrastructure.

## Tiered model routing

Concept borrowed from local-vida: a classifier inspects the request and routes to one of three tiers.

| Tier | When | Examples |
|---|---|---|
| Local | Default. No PII concerns, latency-sensitive, or privacy-sensitive. | On-device transcription, embedding generation, simple classification. |
| Premium-cloud | High-quality reasoning needed AND egress policy permits. | Long-form reasoning, code generation, complex synthesis. |
| Cheap-cloud | Bulk work where quality floor matters less. | Tagging, simple summarization, batch processing. |

This is a **pattern**, not a library commitment. The routing logic lives in the Brain; the underlying model gateway (LiteLLM, custom router, direct SDK calls) is an implementation choice.

## Tool abstraction (MCP-style)

Models that take actions do so through a **bounded toolset**, not direct system access. The MCP (Model Context Protocol) pattern from local-vida is adopted as a concept:

- Tools are registered with name, schema, and required capabilities.
- A model invocation specifies which tools are available; others cannot be called.
- Tool calls go through the same capability + audit-log path as any other API call.
- Different contexts get different toolsets. Conversation has a broader set; autonomous task execution gets a narrower one (initially WebSearch + WebFetch, mirroring local-vida's safety boundary).

## Cloud egress policy

This is the load-bearing section. Cloud LLMs are convenient and powerful, and they are also a privacy hazard.

### Risks

Cloud egress is broader than "training data sharing." Concrete risks:

- **Vendor data retention.** Providers retain logs for varying windows; even "zero retention" agreements have exceptions for abuse review.
- **Server-side logs.** Operational logs may capture prompts and responses outside the formal data-retention scope.
- **Telemetry.** Performance and quality metrics often include sample payloads.
- **Human review.** Trust-and-safety, abuse, and quality processes may surface payloads to humans.
- **Breach exposure.** Provider breaches expose stored data even when retention is short.
- **Policy changes.** Provider terms can change; data sent today is governed by today's terms but stored under tomorrow's.
- **Accidental prompt leakage.** A prompt assembled with stale context can include data the user never intended to share.

### Default and exceptions

**Default: local.** Cloud is reachable only via an **explicit allowlist**, scoped per data class and per provider.

When a cloud call is made, the system must:

1. **Apply redaction rules.** Drop names, dates, locations, and other identifiers when the prompt does not require them.
2. **Verify consent.** Confirm the owner principal of every memory or event included has consented (per-class consent, not blanket).
3. **Record an audit log entry per call.** Provider, model, prompt hash, owner, privacy tier, redaction applied, timestamp.

### Sensitive classes

These never egress without per-event explicit user approval:

- Health and medical.
- Financial.
- School-related (kid data).
- Romantic / relationship.
- Biometric (face embeddings, voice prints, raw camera/audio).

A cloud call attempting to include sensitive-class data without per-event approval is rejected by the Brain before it reaches the network.

## Local-first trajectory

Phase 0 allows broad cloud use to bootstrap quality. The roadmap tightens the allowlist over time:

- **Phase 0–1.** Cloud allowed broadly (under egress policy), local Ollama models stood up alongside.
- **Phase 4.** Cloud allowlist tightened to what local models cannot replace at acceptable quality.
- **Long-term.** Cloud is reserved for truly novel work that local models cannot do.

## Aspect / synthesis (deferred)

mia-sempre's "aspects + Momma Mia synthesis" pattern (parallel partial reasoners feeding into a synthesizer) is a useful idea but **not adopted day-one**. Adding it requires multiple model calls per response and complicates the egress story. Reconsider at Phase 4 when local model quality is high enough to make multi-pass cheap.

## Design Invariants

- **No cloud call without an owner-principal-aware prompt.** The Brain assembles prompts; the AI Router never reads from raw memory tables directly.
- **No cloud call without an audit-log entry.** This is enforced at the router boundary.
- **Sensitive-class data requires per-event approval.** Blanket consent is not enough.
- **Tool calls go through capability checks.** A model "deciding" to call a tool does not bypass capability enforcement.

## Known Decisions

- 🟢 [ADR-0007](../05-decisions/0007-persistent-state-postgres.md) — Postgres holds the audit log of cloud calls.

## Open Questions

- Specific routing classifier (local model? rule-based? hybrid?). Implementation detail; deferred.
- Allowlist UX. How does an admin grant `cloud.use[provider=anthropic, class=general]`? Probably an admin action on the trusted client, audit-logged.

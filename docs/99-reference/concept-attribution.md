# Concept Attribution

What was carried over from each reference repo, what was adapted, what was deferred, and what was rejected. The rule of thumb: **concepts kept, technologies route through ADRs.** When a row says "kept," that's the *idea* — the technology choice routes through ADRs in [05-decisions/](../05-decisions/).

## From local-vida

| Concept | Status | Adopted as |
|---|---|---|
| Event-driven architecture with priority lanes | kept | [01-architecture/event-system.md](../01-architecture/event-system.md) (broker TBD, [ADR-0002](../05-decisions/0002-event-broker.md)) |
| Work-item hierarchy (Project → Feature → Task) with dependencies, comments, status timestamps | kept | [02-domains/projects-and-backlog.md](../02-domains/projects-and-backlog.md) |
| Autonomous task heartbeat (Jarvis pattern) | kept | [02-domains/projects-and-backlog.md](../02-domains/projects-and-backlog.md) + [02-domains/background-processing.md](../02-domains/background-processing.md) |
| Bounded toolset for autonomous execution (initially WebSearch + WebFetch) | kept | [02-domains/projects-and-backlog.md](../02-domains/projects-and-backlog.md), [01-architecture/ai-orchestration.md](../01-architecture/ai-orchestration.md) |
| LiteLLM-style tiered model routing (cheap / premium / local) driven by classifier | kept as **pattern** | [01-architecture/ai-orchestration.md](../01-architecture/ai-orchestration.md). Not bound to LiteLLM specifically. |
| MCP-style tool abstraction | kept as **pattern** | [01-architecture/ai-orchestration.md](../01-architecture/ai-orchestration.md). Not bound to FastMCP. |
| Observability stack ideas (Prometheus, Grafana, Loki, Langfuse for LLM tracing) | kept as **inspiration** | [03-operations/observability.md](../03-operations/observability.md) (stub, stack TBD). |
| Prefect for Python workflow orchestration | kept as **lead candidate** | [02-domains/background-processing.md](../02-domains/background-processing.md), [ADR-0006](../05-decisions/0006-workflow-engine.md) — proposed, not accepted. |
| **Single-user architecture** | **rejected** | Phase 0 in distributed-ai is family-aware. Identity, ownership fields, privacy tiers, and capability checks exist from day one. See [04-roadmap/phases.md](../04-roadmap/phases.md). |
| Specific tech stack (Python, FastAPI, Valkey, Qdrant) | not adopted wholesale | Individual choices route through ADRs; Qdrant is not the Phase 0 vector store ([ADR-0003](../05-decisions/0003-vector-store.md)). |

## From mia-sempre

| Concept | Status | Adopted as |
|---|---|---|
| Persistent agent runtime with event / idle / maintenance loops | kept | [01-architecture/system-overview.md](../01-architecture/system-overview.md) — three loops named explicitly. |
| Multi-user isolated contexts | kept | [02-domains/identity-and-access.md](../02-domains/identity-and-access.md) + [02-domains/memory-and-context.md](../02-domains/memory-and-context.md). |
| Event envelope distinguishing source / actor / subject / owner | kept and extended | [01-architecture/event-system.md](../01-architecture/event-system.md). distributed-ai adds `source_type` + `source_id` (not just `source_device_id`), `publish_capability_required[]`, `subscribe_capability_required[]`, and the **Household** principal as a non-FamilyMember owner. |
| Local-first AI commitment | kept and strengthened | [00-orientation/principles.md](../00-orientation/principles.md) invariant #1, [01-architecture/ai-orchestration.md](../01-architecture/ai-orchestration.md) cloud egress policy. |
| HDTS (Hierarchical Delegation with Temporal Stratification, L1–L4) | kept as **future architectural influence**, deferred to Phase 5 | [01-architecture/brain-to-nerve.md](../01-architecture/brain-to-nerve.md). Day-one is L4 only with thin L2 on Pis. |
| "Goals/constraints, not microcommands" principle | kept | [00-orientation/principles.md](../00-orientation/principles.md) invariant #7. Applied even at L4-only. |
| "One mind, many bodies" framing | kept | [00-orientation/glossary.md](../00-orientation/glossary.md), brain-to-nerve doc. |
| Aspect / Momma Mia synthesis (parallel reasoners + synthesizer) | **deferred** | Mentioned in [01-architecture/ai-orchestration.md](../01-architecture/ai-orchestration.md) as a Phase 4 candidate. Not day-one. |
| Specific tech stack (Python, FastAPI, Valkey, Qdrant, LiteLLM) | not adopted wholesale | Individual choices route through ADRs; Qdrant is not the Phase 0 vector store ([ADR-0003](../05-decisions/0003-vector-store.md)). |

## Explicit rejections

| Item | Reason |
|---|---|
| Phoenix LiveView | UI rendering is the SvelteKit client's job. Excluded regardless of [ADR-0001](../05-decisions/0001-control-plane-language.md). |
| FCM / OneSignal as default mobile push | Privacy footprint conflicts with [00-orientation/principles.md](../00-orientation/principles.md) invariant #1. See [ADR-0008](../05-decisions/0008-mobile-push-notifications.md). |
| Single-user data model | Phase 0 in distributed-ai must be family-aware. |
| Treating event broker as "the system nervous system" that does everything | The five planes ([01-architecture/system-planes.md](../01-architecture/system-planes.md)) keep concerns separate. |

## Net new concepts (not from either repo)

| Concept | Lives in |
|---|---|
| **Household** principal for non-individual ownership | [00-orientation/glossary.md](../00-orientation/glossary.md), [01-architecture/data-model.md](../01-architecture/data-model.md). |
| Privacy tiers (`private-personal`, `family-shared`, `room-safe`, `public-ambient`) | [02-domains/security-and-privacy.md](../02-domains/security-and-privacy.md). |
| The "rash problem" framing | [02-domains/security-and-privacy.md](../02-domains/security-and-privacy.md). |
| Group-aware degradation | [02-domains/perception-and-presence.md](../02-domains/perception-and-presence.md). |
| Five-plane separation (realtime / durable / telemetry / workflow / persistent) | [01-architecture/system-planes.md](../01-architecture/system-planes.md). |
| Capability split: `publish_capability_required[]` vs `subscribe_capability_required[]` | [01-architecture/event-system.md](../01-architecture/event-system.md). |
| Tightening-silent / loosening-explicit memory tier rule | [02-domains/memory-and-context.md](../02-domains/memory-and-context.md). |
| Raw-vs-derived perception split | [02-domains/perception-and-presence.md](../02-domains/perception-and-presence.md). |

# System Overview

## Purpose

Name the major components, their responsibilities, and the runtime loops that hold them together — without committing to any specific technology beyond what's been accepted.

## Components

```
                         ┌─────────────────────────┐
                         │   Web/Mobile Clients    │
                         │  (SvelteKit, mobile)    │
                         └────────────┬────────────┘
                                      │ HTTP + WebSocket
                                      ▼
┌──────────────────────────────────────────────────────────────┐
│                          Brain                               │
│   Control plane · agent runtime · event router · auth        │
│   Runs three loops: event · idle · maintenance               │
│                                                              │
│   Talks to: AI Router, Workflow Runner, Postgres,            │
│             Vector Store, Event Broker                       │
└──────┬──────────┬───────────┬───────────┬──────────┬─────────┘
       │          │           │           │          │
       ▼          ▼           ▼           ▼          ▼
┌──────────┐ ┌────────┐ ┌──────────┐ ┌─────────┐ ┌─────────┐
│ AI Router│ │Workflow│ │ Postgres │ │ Vector  │ │ Event   │
│ (cheap/  │ │ Runner │ │  🟢      │ │ Store   │ │ Broker  │
│ premium/ │ │ (Python│ │ source-of│ │  TBD    │ │  TBD    │
│  local)  │ │ jobs)  │ │  truth)  │ │ ADR-0003│ │ ADR-0002│
│ TBD      │ │ TBD    │ │ ADR-0007 │ │         │ │         │
│          │ │ADR-0006│ │          │ │         │ │         │
└────┬─────┘ └───┬────┘ └──────────┘ └─────────┘ └────┬────┘
     │           │                                    │
     ▼           ▼                                    │
┌──────────┐ ┌──────────────┐                         │
│ AI/ML    │ │ AI/ML Workers │ ◄──── consume events ──┤
│ Workers  │ │ (Python:      │                        │
│ (Python) │ │  vision,      │                        │
│          │ │  embeddings,  │                        │
│          │ │  research...) │                        │
└──────────┘ └───────────────┘                        │
                                                      │
              ┌───────────────────────────────────────┴──┐
              │       Edge Devices                       │
              │   Pis (cameras, avatars, static          │
              │   installs), mobile clients              │
              └──────────────────────────────────────────┘
```

## Component responsibilities

- **Brain** — Always-on control plane. Handles device sessions, capability checks, event routing, and the agent runtime loops. Language choice is open ([ADR-0001](../05-decisions/0001-control-plane-language.md)); strong candidate is a hybrid Elixir/OTP control plane with Python AI workers.
- **AI/ML Workers** — Python processes that do the heavy lifting: vision, face recognition, transcription, embeddings, LLM orchestration, research, coding agents, data analysis. Workers are **not** the event backbone; they consume from it and emit progress back to it.
- **Edge Devices** — Pis with cameras, static installs, mobile phones, laptops. Each one is a registered client under [client-registration.md](../02-domains/client-registration.md).
- **Web/Mobile Clients** — SvelteKit on the web; native mobile (TBD) on phones. Talk to the Brain over HTTP for CRUD and WebSockets for live updates. See [api-and-transport.md](api-and-transport.md).
- **Postgres** 🟢 — Source of truth for durable app state (family principals, devices, capabilities, work items, memories, audit logs). See [ADR-0007](../05-decisions/0007-persistent-state-postgres.md).
- **Vector Store** — For memory embeddings. Choice between pgvector (in Postgres) and Qdrant (separate service) is open ([ADR-0003](../05-decisions/0003-vector-store.md)).
- **Event Broker** — Realtime routing and durable history. Possibly two brokers (one per plane). Open ([ADR-0002](../05-decisions/0002-event-broker.md)).
- **AI Router** — Tiered model routing pattern (cheap / premium / local) driven by a classifier. See [ai-orchestration.md](ai-orchestration.md).
- **Workflow Runner** — Multi-step Python jobs with retries, scheduling, progress events. Prefect leads ([ADR-0006](../05-decisions/0006-workflow-engine.md)).

## Runtime loops

The Brain runs three persistent loops, a concept carried over from mia-sempre:

- **Event loop** — Consume events from the broker, dispatch to handlers, enforce capability checks, emit derived events. This is what keeps the system reactive.
- **Idle loop** — When no events demand immediate attention, the brain runs reflection and planning passes — summarizing recent activity, surfacing follow-ups, advancing background reasoning on assigned work items.
- **Maintenance loop** — Periodic housekeeping: retention sweeps on memories and raw observations, cache warmup, capability re-checks against current grants, audit-log compaction.

These are documented here at the conceptual level. Mechanics belong to whichever language wins [ADR-0001](../05-decisions/0001-control-plane-language.md) — Elixir/OTP supervised processes, Python asyncio tasks, or a hybrid.

## Known Decisions

- 🟢 [ADR-0007](../05-decisions/0007-persistent-state-postgres.md) — Postgres for durable app state.

## Open Questions

- 🟣 [ADR-0001](../05-decisions/0001-control-plane-language.md) — Control plane language (hybrid Elixir+Python leading).
- 🔵 [ADR-0002](../05-decisions/0002-event-broker.md) — Event broker(s).
- 🔵 [ADR-0003](../05-decisions/0003-vector-store.md) — Vector store.
- 🟣 [ADR-0006](../05-decisions/0006-workflow-engine.md) — Workflow engine (Prefect leading).

# distributed-ai

A self-hosted, family-scoped personal AI assistant for the Ritzema family. Runs on owned hardware first; cloud is a bootstrap accelerator only, not a destination.

## Reading order

1. [00-orientation/](00-orientation/) — mission, principles, glossary
2. [01-architecture/](01-architecture/) — components, planes, events, data model
3. [02-domains/](02-domains/) — identity, privacy, registration, perception, memory, work
4. [04-roadmap/](04-roadmap/) — phases and open questions
5. [05-decisions/](05-decisions/) — ADRs (active design decisions)
6. [99-reference/](99-reference/) — pointers to source repos and attribution

## Prototypes

- [`../prototypes/avatar-lab/`](../prototypes/avatar-lab/) — static Wubblefazz avatar/perception client for `home.dinkerwupp.com`.

## Doc status legend

| Marker | Meaning |
|---|---|
| 🟢 Accepted | Decided. Code may rely on it. |
| 🟣 Proposed | Recommendation made; awaiting confirmation. |
| 🔵 Open | Options laid out; no decision yet. |
| 🟡 Stub | TODO line only — placeholder for future content. |

## Currently accepted decisions

| Decision | ADR |
|---|---|
| Postgres is the source of truth for durable app state | [ADR-0007](05-decisions/0007-persistent-state-postgres.md) |
| pgvector in Postgres is the vector store for memory embeddings | [ADR-0003](05-decisions/0003-vector-store.md) |
| Hybrid Elixir/Phoenix control plane + Python AI workers (LiveView excluded; SvelteKit UI) | [ADR-0001](05-decisions/0001-control-plane-language.md) |
| Worker fleet topology: DB on `mac-mini-1`, Brain on `mac-mini-2`, FastAPI worker service + AI model runtimes on Mac Studio | [ADR-0009](05-decisions/0009-worker-fleet-topology.md) |
| Web frontend hosting: SvelteKit SSR on `mac-mini-2` via `@sveltejs/adapter-node` on Bun; one canonical origin per environment (`i.dinkerwupp.com`, `dev.dinkerwupp.com`); Phoenix owns `/api/*` and `/socket` | [ADR-0010](05-decisions/0010-web-frontend-hosting.md) |
| Reverse proxy on `mac-mini-2`: Caddy v2 with `caddy-dns/cloudflare`; DNS-01 ACME against the Cloudflare-hosted `dinkerwupp.com` zone; launchd-supervised | [ADR-0011](05-decisions/0011-reverse-proxy.md) |

Accepted technology choices are Postgres for durable app state, pgvector for memory embeddings, the hybrid Elixir/Phoenix control plane + Python AI workers, the three-host worker fleet topology, web frontend hosting (SvelteKit SSR on `mac-mini-2`), and Caddy as the reverse proxy fronting it. Event broker, realtime transport, device-telemetry protocol, workflow engine, and mobile push provider remain tracked as ADRs in [05-decisions/](05-decisions/).

**Next concrete step:** the [Pre-Phase 0 Phoenix control-plane spike](04-roadmap/phases.md) — a tightly-scoped vertical slice (health endpoint, capability-gated Phoenix Channel, server-pushed event to a SvelteKit client, Python worker → Brain call over HTTP, and a Brain → worker cross-host dispatch to a stub FastAPI endpoint on the Studio) that validates ADR-0001 and ADR-0009 in code without forcing ADR-0002 to close.

## Index

### 00-orientation/
- [overview.md](00-orientation/overview.md) — mission, family roster, non-goals
- [principles.md](00-orientation/principles.md) — the seven architectural invariants
- [glossary.md](00-orientation/glossary.md) — terms, principal types, capability syntax

### 01-architecture/
- [system-overview.md](01-architecture/system-overview.md) — components and runtime loops
- [physical-topology.md](01-architecture/physical-topology.md) — hardware roles and network shape
- [system-planes.md](01-architecture/system-planes.md) — the five planes the system separates
- [api-and-transport.md](01-architecture/api-and-transport.md) — HTTP / WebSocket / push rules
- [event-system.md](01-architecture/event-system.md) — broker-agnostic envelope and concerns
- [data-model.md](01-architecture/data-model.md) — entities, relationships, role distinctions
- [brain-to-nerve.md](01-architecture/brain-to-nerve.md) — HDTS as future influence
- [ai-orchestration.md](01-architecture/ai-orchestration.md) — model routing, tools, cloud egress
- [example-flows.md](01-architecture/example-flows.md) — three end-to-end walkthroughs

### 02-domains/
- [identity-and-access.md](02-domains/identity-and-access.md) — principals, roles, default rules
- [security-and-privacy.md](02-domains/security-and-privacy.md) — privacy tiers, the rash problem, biometrics
- [client-registration.md](02-domains/client-registration.md) — pairing, identity, capabilities, revocation
- [perception-and-presence.md](02-domains/perception-and-presence.md) — raw observations vs derived presence
- [projects-and-backlog.md](02-domains/projects-and-backlog.md) — work items and the autonomous heartbeat
- [memory-and-context.md](02-domains/memory-and-context.md) — categories, retention, cloud boundaries
- [background-processing.md](02-domains/background-processing.md) — workflow role and lifecycle

### 03-operations/
- [caddy.md](03-operations/caddy.md) — Caddy build, Cloudflare token, validation, and launchd handoff runbook
- [deployment.md](03-operations/deployment.md) 🟡
- [observability.md](03-operations/observability.md) 🟡

### 04-roadmap/
- [phases.md](04-roadmap/phases.md) — phased delivery plan
- [open-questions.md](04-roadmap/open-questions.md) — living list, links to ADRs

### 05-decisions/
- [0000-template.md](05-decisions/0000-template.md) — ADR template
- [0001-control-plane-language.md](05-decisions/0001-control-plane-language.md) 🟢 hybrid Elixir+Python accepted
- [0002-event-broker.md](05-decisions/0002-event-broker.md) 🟣 staged Phoenix + Postgres outbox → NATS later
- [0003-vector-store.md](05-decisions/0003-vector-store.md) 🟢 pgvector accepted
- [0004-realtime-transport.md](05-decisions/0004-realtime-transport.md) 🟣 Phoenix Channels leading
- [0005-device-telemetry-protocol.md](05-decisions/0005-device-telemetry-protocol.md) 🟣 MQTT favored for Pis
- [0006-workflow-engine.md](05-decisions/0006-workflow-engine.md) 🟣 Prefect leading
- [0007-persistent-state-postgres.md](05-decisions/0007-persistent-state-postgres.md) 🟢 accepted
- [0008-mobile-push-notifications.md](05-decisions/0008-mobile-push-notifications.md) 🔵 (Phase 3)
- [0009-worker-fleet-topology.md](05-decisions/0009-worker-fleet-topology.md) 🟢 three-host split accepted
- [0010-web-frontend-hosting.md](05-decisions/0010-web-frontend-hosting.md) 🟢 SvelteKit SSR on mac-mini-2 accepted
- [0011-reverse-proxy.md](05-decisions/0011-reverse-proxy.md) 🟢 Caddy v2 with cloudflare DNS-01 accepted

### 99-reference/
- [reference-repos.md](99-reference/reference-repos.md) — local-vida and mia-sempre pointers
- [concept-attribution.md](99-reference/concept-attribution.md) — what was kept, adapted, deferred, rejected

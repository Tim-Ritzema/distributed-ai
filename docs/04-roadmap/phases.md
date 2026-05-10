# Phases

## Purpose

Phased delivery plan. Cloud-first early, local-later. **Family scoping is in Phase 0**, not retrofitted later.

## Pre-Phase 0 — Phoenix control-plane spike

Before full Phase 0 implementation, validate [ADR-0001](../05-decisions/0001-control-plane-language.md) with the smallest useful Phoenix vertical slice:

- `GET /health` endpoint.
- Postgres connection and one trivial migration/query.
- One Phoenix Channel with a capability-gated topic join.
- One server-pushed event to a SvelteKit client.
- One Python script or worker call into the Brain over HTTP.
- No NATS/JetStream requirement for the spike; [ADR-0002](../05-decisions/0002-event-broker.md) remains proposed, not accepted, until the broker boundary is decided explicitly.

This spike is a learning-risk reducer, not a feature milestone. If Phoenix feels wrong after this slice, revisit [ADR-0001](../05-decisions/0001-control-plane-language.md) before building deeper.

## Phase 0 — Family-aware foundation

The minimum viable system that's structurally correct from day one.

**In scope:**

- Brain (control plane + agent runtime) on the Mac Studio.
- Postgres (the accepted source of truth, [ADR-0007](../05-decisions/0007-persistent-state-postgres.md)).
- Event broker (whichever wins [ADR-0002](../05-decisions/0002-event-broker.md)).
- One personal chat client (web or mobile, Tim-owned), talking HTTP+WebSocket.
- **Family-aware identity model** — all six FamilyMembers + Household principal in the database from the start, even though only Tim actively uses a client.
- **Capability checks present** — the API and event broker both enforce capability requirements, even if Tim's capability set covers everything by default.
- **Privacy tiers in the data model** — every memory and event has a tier from creation.
- Cloud LLMs allowed under the [cloud egress policy](../01-architecture/ai-orchestration.md).
- Single active user (Tim); multi-user data model already in place.

**Explicitly out:**

- Other family members onboarding (Phase 1).
- Pi static installs (Phase 2).
- Mobile app (Phase 3).

**Why this composition:** Phase 0 is "single active user, family-aware foundation." Building the family-aware structures now is cheap; bolting them on after the system has data is expensive and error-prone.

## Phase 1 — Family onboarded

**In scope:**

- Laurie and the kids onboarded as principals with their own clients.
- Client registration handshake fully working (pairing, admin approval, capability grants).
- Work-item APIs live ([projects-and-backlog.md](../02-domains/projects-and-backlog.md)).
- Live job progress streaming over WebSocket.
- Cross-principal access enforcement validated (Bennett can't read Tim's private data, parents can read kid data).

## Phase 2 — First Pi static install

**In scope:**

- One Pi with camera and display, paired and capability-scoped.
- Raw-vs-derived perception split implemented.
- Group-aware degradation enforced.
- Rash-problem rules verified end-to-end.
- Avatar visualization on the static install (presentation by the client; brain emits state).

## Phase 3 — Mobile app

**In scope:**

- Native mobile app (or polished PWA) with pairing flow.
- Mobile push for backgrounded clients ([ADR-0008](../05-decisions/0008-mobile-push-notifications.md) closes here).
- Push-and-reconnect-WS pattern wired up.

## Phase 4 — Local-first inference

**In scope:**

- Local Ollama-class models capable of replacing common cloud calls.
- Cloud allowlist tightened to specific cases.
- Sensitive-class data restricted to local processing entirely.
- Possibly: aspect/synthesis pattern from mia-sempre adopted if local quality supports multi-pass.

## Phase 5 — Optional: HDTS L2/L3

**Trigger:** physical embodiment becomes a goal (a robot, a farmbot, an actuated device joins the system).

**In scope:**

- HDTS L2 (skill execution) on capable devices.
- HDTS L3 (motor planning) where applicable.
- L1 (hard-real-time reflexes) as needed for safety.

Until the trigger fires, [brain-to-nerve.md](../01-architecture/brain-to-nerve.md) remains documentation, not code.

## Cross-cutting

Through every phase:

- **Postgres is the source of truth.** Every other store is a cache, derived index, or event log.
- **Cloud egress policy enforced.** Tightens over phases.
- **Audit logging on.** Every cross-tier or cross-principal access logged.
- **ADRs filled.** Open decisions don't linger in roadmap; they get accepted, amended, or superseded.

## Open Questions

See [open-questions.md](open-questions.md) for the full live list. Highlights for early phases:

- 🟢 [ADR-0001](../05-decisions/0001-control-plane-language.md) — control plane language. **Closed** before Phase 0 implementation: hybrid Elixir/Phoenix + Python AI workers.
- 🟣 [ADR-0002](../05-decisions/0002-event-broker.md) — event broker. Needs to be accepted before full Phase 0, not before the Phoenix spike.
- 🔵 [ADR-0003](../05-decisions/0003-vector-store.md) — vector store. Needs to close before memory embeddings ship (Phase 0 or 1).
- 🟣 [ADR-0006](../05-decisions/0006-workflow-engine.md) — workflow engine. Needs to close before any workflows ship (Phase 1).

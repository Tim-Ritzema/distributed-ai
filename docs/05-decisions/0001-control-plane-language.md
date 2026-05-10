# ADR-0001: Control plane language

**Status:** 🟢 accepted (hybrid Elixir/OTP control plane + Python AI workers)

## Context

The Brain is the always-on control plane: device sessions, WebSocket fanout, event routing, capability checks, supervised long-running processes (event/idle/maintenance loops), presence tracking. Whatever language hosts this code shapes operational ergonomics for the next several years.

Reference repos used Python (local-vida) and Python (mia-sempre). **Those are not commitments** — they're concept POCs. The user has explicitly asked for the language decision to be re-opened.

Constraints / preferences:

- **Phoenix LiveView is excluded.** UI rendering is the SvelteKit client's job, not the server's.
- **SvelteKit is the preferred web UI**, regardless of backend.
- **AI/ML workers stay in Python.** Vision, transcription, embeddings, LLM orchestration, and research workflows have their best ecosystem there. This isn't under debate.
- The control plane has heavy realtime fanout, supervision, and concurrent device sessions — workloads where Erlang/OTP traditionally excels.

## Options

### Option A — Elixir/Phoenix/OTP control plane + Python AI workers (hybrid)

- **Pros:**
  - OTP supervision, GenServers, and `:pg` / Phoenix.PubSub fit the always-on control-plane shape natively.
  - Phoenix.Channels (or plain WebSocket) handle thousands of concurrent device sessions efficiently.
  - Built-in presence tracking is well-tested.
  - Hot code reload and crash recovery come for free.
  - Python keeps doing what Python does best (workers).
- **Cons:**
  - Two languages to maintain. Two test stories, two CI configurations.
  - Smaller talent pool (one-developer project today, but consider future).
  - Cross-language event contracts need explicit care (schema validation at the boundary).

### Option B — Python/FastAPI throughout

- **Pros:**
  - Single language.
  - Mirrors local-vida; quickest path to Phase 0.
  - One ecosystem for everything.
- **Cons:**
  - Async Python under sustained realtime fanout is workable but fiddly. Worker contention can hurt the control plane.
  - Long-running supervised processes are not Python's natural shape.
  - WebSocket scaling and presence tracking require additional libraries and care.

### Option C — Elixir/Phoenix + NATS/JetStream + Python workers

Like A, but with NATS/JetStream explicitly chosen as a first-class broker behind the Elixir control plane. This is not really a competing control-plane language choice; it folds part of [ADR-0002](0002-event-broker.md) into this ADR.

- **Pros:**
  - NATS handles event routing better than ad-hoc PubSub for the durable-history plane.
  - Cleaner story for cross-machine event distribution as the system grows.
- **Cons:**
  - Conflates the language/runtime decision with the broker decision.
  - More moving parts. Three things to deploy and operate.
  - Probably overkill for a household-scale system in Phase 0.

## Decision

**Accepted: Option A — hybrid Elixir/OTP control plane + Python AI workers.**

The control plane's shape — long-lived sessions, supervised loops, concurrent fanout — fits OTP. The AI work — vision, transcription, LLMs — fits Python. Two languages is a real cost, but it's a cost that buys reliability and concurrency story that matter for an always-on family system.

This decision does **not** reject NATS/JetStream. It deliberately keeps the broker choice in [ADR-0002](0002-event-broker.md), where realtime fanout and durable event history can be evaluated separately from the Brain runtime.

## Consequences

- The Brain is an Elixir application, Phoenix-based for HTTP + WebSockets. **Phoenix LiveView is not used** — the UI runs on SvelteKit.
- Python workers communicate with the Brain over HTTP and whichever event boundary [ADR-0002](0002-event-broker.md) accepts.
- Cross-language contracts get explicit schema validation (probably a shared schema repo or generated bindings).
- [ADR-0004](0004-realtime-transport.md) — Phoenix Channels become the proposed realtime transport for SvelteKit clients, with plain WebSockets remaining as a viable fallback.
- [ADR-0006](0006-workflow-engine.md) — Oban becomes a real candidate for simple Elixir-side background jobs (sweeps, schedule ticks), complementary to Prefect for Python AI workflows.
- [ADR-0002](0002-event-broker.md) — Phoenix.PubSub / Phoenix.Channels becomes a stronger candidate for connected-client fanout inside the Brain, but NATS/JetStream remains a valid broker candidate behind the Brain. The broker boundary and durable history choice remain open.
- Operational footprint adds an Elixir runtime alongside Python; deployment doc ([03-operations/deployment.md](../03-operations/deployment.md)) firms up after [ADR-0002](0002-event-broker.md) closes.

## References

- [01-architecture/system-overview.md](../01-architecture/system-overview.md) — control plane component description.
- [04-roadmap/phases.md](../04-roadmap/phases.md) — closed before the Pre-Phase 0 Phoenix control-plane spike, which validates this decision in code.
- [ADR-0004](0004-realtime-transport.md) — informed by this decision.

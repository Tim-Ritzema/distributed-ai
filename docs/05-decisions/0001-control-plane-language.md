# ADR-0001: Control plane language

**Status:** 🟣 proposed (hybrid Elixir/OTP control plane + Python workers leading)

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

### Option C — Elixir + NATS + Python workers

Like A, but with NATS as a first-class event bus on the Elixir side, possibly displacing Phoenix.PubSub for cross-process routing.

- **Pros:**
  - NATS handles event routing better than ad-hoc PubSub for the durable-history plane.
  - Cleaner story for cross-machine event distribution as the system grows.
- **Cons:**
  - More moving parts. Three things to deploy and operate.
  - Probably overkill for a household-scale system in Phase 0.

## Decision

**Proposed:** Option A (hybrid Elixir/OTP control plane + Python AI workers). The control plane's shape — long-lived sessions, supervised loops, concurrent fanout — fits OTP. The AI work — vision, transcription, LLMs — fits Python. Two languages is a real cost, but it's a cost that buys reliability and concurrency story that matter for an always-on family system.

Awaiting confirmation; if rejected, fallback is Option B for speed.

## Consequences

If accepted:

- The Brain is an Elixir application, likely Phoenix-based for HTTP + WebSockets (without LiveView).
- Python workers communicate with the Brain over the event bus and HTTP.
- Cross-language contracts get explicit schema validation (probably a shared schema repo or generated bindings).
- [ADR-0004](0004-realtime-transport.md) gains a strong default of Phoenix Channels for SvelteKit clients (but plain WS remains viable).

If rejected in favor of B:

- Single-language project, faster to ship Phase 0.
- More careful design needed for the supervised-loop story (asyncio + task supervision).
- [ADR-0004](0004-realtime-transport.md) defaults to plain WebSockets.

## References

- [01-architecture/system-overview.md](../01-architecture/system-overview.md) — control plane component description.
- [04-roadmap/phases.md](../04-roadmap/phases.md) — needs to close before Phase 0 implementation begins.
- [ADR-0004](0004-realtime-transport.md) — depends on this decision.

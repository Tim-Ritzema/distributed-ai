# ADR-0004: Realtime transport

**Status:** 🟣 proposed (Phoenix Channels leading; awaiting confirmation)

## Context

SvelteKit clients (web portal, possibly mobile via webview) need a realtime push channel from the Brain ([01-architecture/api-and-transport.md](../01-architecture/api-and-transport.md)). [ADR-0001](0001-control-plane-language.md) is now accepted (hybrid Elixir/Phoenix + Python AI workers), which makes Phoenix Channels the natural fit on the realtime UI side.

**Phoenix LiveView is explicitly excluded** — UI rendering is the SvelteKit client's job.

## Options

### Option A — Plain WebSockets

Standard WebSocket protocol, custom message framing.

- **Pros:**
  - Works against any backend (Elixir, Python, Go, anything).
  - Wide tooling, easy to debug with browser devtools.
  - SvelteKit has straightforward WS client support.
  - Fewer abstractions; the wire format is whatever we define.
- **Cons:**
  - Every operational concern (reconnect, heartbeat, channel multiplexing, presence) is on us.
  - No standard ack/replay semantics; we build them.

### Option B — Phoenix Channels

With [ADR-0001](0001-control-plane-language.md) accepting Elixir/Phoenix, Phoenix Channels are the natural realtime layer.

- **Pros:**
  - Built-in topic multiplexing, ack semantics, presence tracking, reconnect.
  - Battle-tested at scale.
  - First-class SvelteKit clients exist (e.g., `phoenix-js` works fine in Svelte).
  - Tightly integrated with `Phoenix.PubSub` for cross-process fanout.
- **Cons:**
  - Phoenix-specific protocol on the wire; harder to swap backends later.
  - Adds Phoenix as a dependency even if the rest of the app is minimal.

### Option C — Server-Sent Events (SSE)

One-way push, simpler than WebSockets.

- **Pros:**
  - Simpler protocol; just an HTTP stream.
  - Auto-reconnect built into browsers.
- **Cons:**
  - One-way only; client → server still needs HTTP requests.
  - Doesn't fit bidirectional flows (assistant token streaming with interruption support).

## Decision

**Proposed: Option B — Phoenix Channels** for SvelteKit clients. Recommendation made; awaiting confirmation.

Rationale:

- ADR-0001 accepted Elixir/Phoenix for the control plane; Phoenix Channels is the matching realtime layer.
- Built-in topic multiplexing, ack semantics, presence tracking, and reconnect are all things we'd otherwise build.
- Tightly integrated with `Phoenix.PubSub` for cross-process fanout inside the Brain.

If rejected, the fallback is **Option A — plain WebSockets**. Building Phoenix-equivalent features over plain WS is real work but not impossible.

SSE (Option C) is a fallback for narrow cases (long-running one-way streams) but not the primary realtime transport.

**Independent of the broker behind the Brain.** This ADR governs the Brain ↔ SvelteKit client transport. Whichever broker [ADR-0002](0002-event-broker.md) picks (Phoenix.PubSub-only, NATS/JetStream, Postgres outbox, or staged) lives *behind* the Brain — clients never subscribe to it directly. The Brain remains the capability-enforcement point for client-visible events regardless.

## Consequences

If Phoenix Channels accepted:

- SvelteKit clients use a Phoenix-aware client library (e.g., `phoenix-js`). Modest learning curve.
- Backend can multiplex many topics over one socket per client.
- Migration to a non-Elixir backend later would be real work — but the rest of the system is now committed to Elixir, so this risk is small.

If rejected in favor of plain WebSockets:

- We define our own message envelope (probably mirroring the event envelope in [01-architecture/event-system.md](../01-architecture/event-system.md)).
- Need to build reconnect, heartbeat, ack semantics ourselves.

## References

- [01-architecture/api-and-transport.md](../01-architecture/api-and-transport.md)
- [ADR-0001](0001-control-plane-language.md) — informed by accepted ADR-0001.

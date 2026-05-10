# ADR-0004: Realtime transport

**Status:** 🔵 open

## Context

SvelteKit clients (web portal, possibly mobile via webview) need a realtime push channel from the Brain ([01-architecture/api-and-transport.md](../01-architecture/api-and-transport.md)). The choice of transport interacts with [ADR-0001](0001-control-plane-language.md).

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

If [ADR-0001](0001-control-plane-language.md) chooses Elixir, Phoenix Channels are the natural realtime layer.

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

**Open.** Strongly conditional on [ADR-0001](0001-control-plane-language.md):

- If Elixir wins ADR-0001: lean toward Phoenix Channels (Option B) for the operational features it brings.
- If Python wins ADR-0001: lean toward plain WebSockets (Option A); building Phoenix-equivalent features in Python is more friction than it's worth.

SSE (Option C) is a fallback for narrow cases (long-running one-way streams) but not the primary realtime transport.

## Consequences

If Phoenix Channels:

- SvelteKit clients use a Phoenix-aware client library. Modest learning curve.
- Backend can multiplex many topics over one socket per client.
- Migration to a non-Elixir backend later is real work.

If plain WebSockets:

- We define our own message envelope (probably mirroring the event envelope in [01-architecture/event-system.md](../01-architecture/event-system.md)).
- Need to build reconnect, heartbeat, ack semantics ourselves.
- Backend-agnostic.

## References

- [01-architecture/api-and-transport.md](../01-architecture/api-and-transport.md)
- [ADR-0001](0001-control-plane-language.md) — strongly influences this decision.

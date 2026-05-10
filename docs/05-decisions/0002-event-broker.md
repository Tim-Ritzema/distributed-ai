# ADR-0002: Event broker(s)

**Status:** 🔵 open

## Context

The system separates five planes ([01-architecture/system-planes.md](../01-architecture/system-planes.md)). Two of those — **realtime event routing** and **durable event history** — both want a broker, but they have different requirements:

- **Realtime:** low latency, high fanout to many subscribers, fire-and-forget OK, short retention, capability-gated subscribe.
- **Durable history:** append-only, replayable, long retention, indexed by `correlation_id`, source for audit and analytics.

Trying to satisfy both with one broker leads to compromises. The likely outcome of this ADR is **two brokers** (or one broker that genuinely covers both, plus a separate IoT lane — see [ADR-0005](0005-device-telemetry-protocol.md)).

## Options

### Option A — Valkey Streams (single broker for both planes)

- **Pros:**
  - One service to operate.
  - Reasonable durability via Streams + consumer groups; fanout via pub/sub.
  - Pattern proven in local-vida.
  - Low operational complexity.
- **Cons:**
  - Replay semantics aren't as rich as JetStream.
  - Memory-resident; tuning retention can be fiddly.

### Option B — NATS JetStream (single broker for both planes)

- **Pros:**
  - Purpose-built for event-driven systems.
  - Durable streams, replay, ack/redeliver, consumer cursors — all first-class.
  - Lightweight; runs well alongside Postgres.
  - Strong fit for cross-machine routing as the system grows.
- **Cons:**
  - Another service to learn and operate.
  - Less familiar than Postgres/Valkey for some developers.

### Option C — Postgres-backed events (LISTEN/NOTIFY + outbox)

- **Pros:**
  - No new service. Postgres is already the source of truth.
  - Outbox pattern gives transactional guarantees with the rest of the data.
  - LISTEN/NOTIFY handles realtime fanout for modest scale.
- **Cons:**
  - LISTEN/NOTIFY isn't replayable; durable history needs separate query path.
  - Scaling fanout has limits; not great if the Pi count grows.
  - All event traffic competes with regular DB queries for connection slots.

### Option D — Hybrid (e.g., NATS for realtime, Postgres outbox for durable)

- **Pros:**
  - Each plane uses the right tool.
  - Postgres outbox stays transactional with persistent state.
  - NATS handles realtime cleanly.
- **Cons:**
  - Two brokers to operate (plus the durable side via Postgres).
  - Cross-plane consistency requires explicit handoff (write outbox, then publish).

### Option E — MQTT for the IoT lane (combined with one of the above for the rest)

This is more about [ADR-0005](0005-device-telemetry-protocol.md) — device telemetry probably wants its own protocol regardless of what handles the other planes.

## Decision

**Open.** Decision criteria for closing:

- How many concurrent subscribers does the Brain need to fanout to in steady state? (Probably tens, not thousands. This favors lighter-weight options.)
- How important is replay? (Important for audit and workflow correlation. Argues for a real durable plane.)
- How much do we care about transactional guarantees between durable state and event history? (Probably a lot. Argues for outbox pattern.)
- ADR-0001 has accepted Elixir/Phoenix for the control plane. Phoenix.PubSub / Phoenix.Channels is now a stronger candidate for realtime fanout, but **ADR-0002 remains open** for the realtime/durable broker boundary and the durable history choice. Don't accidentally close this ADR by leaning on Phoenix.PubSub for all of it.

Provisional lean: Option D (hybrid NATS + Postgres outbox), but no commitment.

## Consequences

The decision shapes:

- [01-architecture/event-system.md](../01-architecture/event-system.md) — concrete broker capabilities.
- [01-architecture/system-planes.md](../01-architecture/system-planes.md) — which plane uses which broker.
- [03-operations/deployment.md](../03-operations/deployment.md) — services to deploy.
- Performance characteristics of every realtime feature.

## References

- [01-architecture/system-planes.md](../01-architecture/system-planes.md)
- [01-architecture/event-system.md](../01-architecture/event-system.md)
- [ADR-0005](0005-device-telemetry-protocol.md) — IoT lane is separate.

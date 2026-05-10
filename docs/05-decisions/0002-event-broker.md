# ADR-0002: Event broker(s)

**Status:** 🟣 proposed (Option F for the Phoenix spike → Option D for scale-out; staged path leading)

## Context

The system separates five planes ([01-architecture/system-planes.md](../01-architecture/system-planes.md)). Two of those — **realtime event routing** and **durable event history** — both want a broker, but they have different requirements:

- **Realtime:** low latency, high fanout to many subscribers, fire-and-forget OK, short retention, capability-gated subscribe.
- **Durable history:** append-only, replayable, long retention, indexed by `correlation_id`, source for audit and analytics.

Trying to satisfy both with one broker leads to compromises. The answer may be one broker that genuinely covers both, two technologies, or a staged path that starts simple and adds a broker later. The separate IoT lane is tracked in [ADR-0005](0005-device-telemetry-protocol.md).

The broker is an internal system boundary behind the Brain. Family clients talk to the Brain over HTTP + Phoenix Channels / WebSockets ([ADR-0004](0004-realtime-transport.md)); they do not subscribe directly to NATS subjects, JetStream consumers, Postgres notifications, or Valkey streams. The Brain is the capability enforcement point for client-visible events.

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

### Option F — Staged Phase 0: Phoenix realtime + Postgres outbox, add NATS later if needed

Use Phoenix Channels / Phoenix.PubSub for connected-client fanout inside the Brain, and a Postgres outbox/event table for transactional durable history. Add NATS/JetStream later if cross-machine routing, replay, redelivery, or worker distribution requirements outgrow the simpler setup.

- **Pros:**
  - Smallest Phase 0 operational footprint: Brain + Postgres.
  - Validates the Elixir/Phoenix control plane before adding a broker.
  - Postgres outbox stays transactional with persistent state.
  - Keeps NATS/JetStream available as a deliberate scale-out step rather than a default dependency.
- **Cons:**
  - Phoenix.PubSub is not a durable event backbone.
  - Worker queues and replay are weaker until NATS/JetStream is added.
  - Adding NATS later requires an explicit bridge from the outbox / Brain event router.

## Decision

**Proposed: staged path — Option F → Option D.** Awaiting confirmation from the Phoenix control-plane spike ([04-roadmap/phases.md](../04-roadmap/phases.md)).

Decision criteria still in play for full acceptance:

- How many concurrent subscribers does the Brain need to fanout to in steady state? (Probably tens, not thousands. This favors lighter-weight options.)
- How important is replay? (Important for audit and workflow correlation. Argues for a real durable plane.)
- How much do we care about transactional guarantees between durable state and event history? (Probably a lot. Argues for outbox pattern.)
- ADR-0001 has accepted Elixir/Phoenix for the control plane. Phoenix.PubSub / Phoenix.Channels is now a stronger candidate for realtime fanout, but **ADR-0002 remains open** for the realtime/durable broker boundary and the durable history choice. Don't accidentally close this ADR by leaning on Phoenix.PubSub for all of it.

Provisional lean: Option F for the first Phoenix validation pass, then Option D if/when the system needs a real broker behind the Brain. The trigger for NATS/JetStream is not "Phoenix exists"; it is a concrete need for broker-level replay, durable consumers, queue groups, cross-machine worker distribution, or richer redelivery semantics.

If NATS/JetStream is adopted, it remains behind the Brain. SvelteKit clients still use Phoenix Channels / WebSockets, and capability checks for client-visible subscriptions still happen in the Brain.

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

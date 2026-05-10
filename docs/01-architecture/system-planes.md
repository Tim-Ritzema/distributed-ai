# System Planes

## Purpose

Five distinct concerns the system separates cleanly. Confusing them is the most common architectural mistake in this kind of project — "we have an event bus" gets used for everything from realtime UI streaming to durable audit storage to workflow orchestration, and the abstractions break down quickly. This doc names each plane and points to its governing ADR.

## The five planes

| Plane | Purpose | Latency target | Tech status |
|---|---|---|---|
| Realtime event routing | Low-latency fanout to live subscribers (assistant tokens, avatar state, presence updates) | < 100ms | 🔵 [ADR-0002](../05-decisions/0002-event-broker.md) |
| Durable event history | Append-only log for audit, replay, analytics, workflow correlation | Seconds | 🔵 [ADR-0002](../05-decisions/0002-event-broker.md) |
| Device telemetry | High-volume sensor / heartbeat ingest from Pis and IoT-class devices | Seconds | 🟣 [ADR-0005](../05-decisions/0005-device-telemetry-protocol.md) (MQTT favored) |
| Workflow orchestration | Multi-step Python jobs with retries, scheduling, visibility | Minutes-to-hours | 🟣 [ADR-0006](../05-decisions/0006-workflow-engine.md) (Prefect leading) |
| Persistent app state | Durable CRUD truth | Transactional | 🟢 [ADR-0007](../05-decisions/0007-persistent-state-postgres.md) — Postgres |

## Why separate them

- **Realtime routing wants low latency and fanout**, but doesn't need durability per message. Many subscribers, short-lived consumers, fire-and-forget OK.
- **Durable history wants append-only, replayable, indexed by correlation_id**, but doesn't need sub-millisecond delivery. Few writers (the broker forwards), many auditors / analyzers.
- **Device telemetry has different traffic patterns** — many publishers, lossy networks, intermittent connectivity, structured QoS needs. MQTT is purpose-built for this.
- **Workflow orchestration tracks long-running multi-step jobs** with retries, branching, and human-in-the-loop. Conflating this with "events" makes both worse.
- **Persistent state is the source of truth.** Everything else can be reconstructed from it (or from the durable event log feeding it).

Different planes can use different technologies. [ADR-0002](../05-decisions/0002-event-broker.md) may choose one broker, separate realtime/durable technologies, or a staged path that starts with Phoenix realtime plus Postgres durable history and adds NATS/JetStream later if needed.

## How the planes interact

A typical event flow touches multiple planes:

1. Kitchen Pi observes Tim, publishes `perception.face.seen` to the **device telemetry plane** (MQTT).
2. The Brain ingests, validates, enriches, and forwards a derived `presence.changed` event to the **realtime routing plane**.
3. The Brain also writes the original observation to the **durable event history plane** (with retention rules per [perception-and-presence.md](../02-domains/perception-and-presence.md)).
4. A subscribed static install receives the realtime event and decides whether to greet ([example-flows.md](example-flows.md) flow #1).
5. Independently, a scheduled retention job runs on the **workflow orchestration plane** to sweep old raw observations.
6. Throughout, **persistent state** in Postgres holds presence state, audit log entries, and capability checks.

## Design Invariants

- **Each plane has one governing ADR.** When the system uses a technology for a plane, you can name the ADR.
- **Cross-plane handoffs go through the Brain**, not directly between brokers. The Brain is where capability checks, schema validation, and tier enforcement happen.
- **No plane is the "default."** When introducing a new event type, decide which plane it belongs on; don't pick the most familiar broker by reflex.

## Known Decisions

- 🟢 [ADR-0007](../05-decisions/0007-persistent-state-postgres.md) — Postgres is the persistent state plane.

## Open Questions

- 🔵 [ADR-0002](../05-decisions/0002-event-broker.md) — realtime + durable broker(s).
- 🟣 [ADR-0005](../05-decisions/0005-device-telemetry-protocol.md) — device telemetry protocol (MQTT favored).
- 🟣 [ADR-0006](../05-decisions/0006-workflow-engine.md) — workflow engine (Prefect leading).

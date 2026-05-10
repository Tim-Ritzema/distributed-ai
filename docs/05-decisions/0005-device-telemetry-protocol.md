# ADR-0005: Device telemetry protocol

**Status:** 🟣 proposed (MQTT favored for Pis)

## Context

Raspberry Pis (and future IoT-class devices) publish telemetry: perception events, sensor readings, heartbeats, status updates. This traffic has different characteristics from the realtime UI plane:

- Many publishers (one per Pi, scaling slowly).
- Lossy networks (Wi-Fi, possibly across the house).
- Intermittent connectivity (a Pi rebooting, a router dropping).
- Need for QoS levels (heartbeat at-most-once is fine; perception at-least-once).
- Constrained devices (a Pi has less CPU than the Brain).

This is the device telemetry plane in [01-architecture/system-planes.md](../01-architecture/system-planes.md).

## Options

### Option A — MQTT (recommended)

- **Pros:**
  - Purpose-built for IoT-style traffic. Decades of deployment experience.
  - QoS levels (0/1/2) baked in. Choose per topic.
  - Last-Will-and-Testament gives clean disconnect handling.
  - Topic ACLs map naturally to our capability model.
  - Lightweight client libraries on every Pi-class platform.
  - Brokers (Mosquitto, EMQX, HiveMQ) are mature and operationally well-understood.
- **Cons:**
  - Yet another protocol to operate alongside HTTP and WebSockets.
  - Bridging MQTT into the realtime/durable planes requires explicit handoff in the Brain.

### Option B — WebSockets (one protocol everywhere)

Use the same WebSocket transport as personal clients ([ADR-0004](0004-realtime-transport.md)) for Pis too.

- **Pros:**
  - One transport to learn, debug, and authenticate.
  - Pi clients look identical to mobile/web clients from the auth side.
- **Cons:**
  - No QoS levels — application-layer reimplementation needed.
  - WebSockets are heavier on lossy networks (TCP-only, no UDP/QoS layering).
  - Last-Will-and-Testament has no equivalent; disconnect handling is roll-your-own.

### Option C — HTTP polling

Simplest possible: Pis POST events on an interval.

- **Pros:**
  - Trivial to implement.
  - Works against any HTTP-aware Brain.
- **Cons:**
  - Latency-bound by the polling interval.
  - No real-time push.
  - Wasteful for low-event-rate devices.

## Decision

**Proposed: Option A (MQTT) for Pi-class devices.** Recommendation made; awaiting confirmation.

Rationale:

- The Pi/IoT shape is exactly what MQTT was built for. Reinventing QoS, last-will, and topic ACLs in WebSockets is more work than running an MQTT broker.
- The capability model maps cleanly onto MQTT topic ACLs (publish capability, subscribe capability — same vocabulary).
- Operational maturity: Mosquitto runs comfortably on the Brain itself or on a small accompanying host.

This decision applies **only** to the device telemetry plane. Personal clients (web, mobile) still use HTTP + WebSockets — see [ADR-0004](0004-realtime-transport.md).

## Consequences

If accepted:

- An MQTT broker is part of the deployed system.
- The Brain bridges from MQTT into the realtime/durable planes, applying schema validation and capability checks at the bridge boundary.
- Pi clients use an MQTT library and the same long-lived keypair for auth (probably client-cert based).
- [03-operations/deployment.md](../03-operations/deployment.md) gains an MQTT broker.

## References

- [01-architecture/api-and-transport.md](../01-architecture/api-and-transport.md) — three transport categories.
- [01-architecture/system-planes.md](../01-architecture/system-planes.md) — device telemetry plane.
- [02-domains/perception-and-presence.md](../02-domains/perception-and-presence.md) — what Pis publish.

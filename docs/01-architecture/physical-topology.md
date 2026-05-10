# Physical Topology

## Purpose

What hardware plays which role, where it lives, and how it's reached.

## Hardware roles

| Role | Hardware | Notes |
|---|---|---|
| Brain (compute) | Mac Studio, garage | Day-one host for control plane + AI workers + Postgres. |
| Database (later) | Mac mini (accompanying) | Postgres moves here if the Studio gets overloaded. |
| Static installations | Raspberry Pi + camera + display | One per room, scaling slowly. Run thin perception (face detect, wake word) and avatar UI. |
| Personal mobile | iPhone / iPad | One per family member who uses one. |
| Personal desktop | Laptops, family computer | Web portal access. |
| Future bodies | Robots, farmbot, etc. | HDTS L2/L3 territory; out of day-one scope. |

## Network shape

- **LAN-first.** All devices and services normally communicate over the home LAN. The Brain has a stable internal address; clients reach it directly.
- **Off-LAN access via VPN.** Mobile clients away from the house reach the Brain through a wireguard/Tailscale-style mesh. No public-facing endpoints.
- **No untrusted ingress.** Even on-LAN, every connection authenticates per [client-registration.md](../02-domains/client-registration.md).

## Migration paths

The day-one topology is intentionally simple — everything on one Mac Studio. Anticipated migrations:

1. **Postgres moves to the mini.** Trigger: Brain CPU/IO contention starts hurting interactive latency. The mini becomes a dedicated DB host on the LAN; the Brain talks to it over the wire.
2. **AI/ML workers split across machines.** Trigger: a single workload (e.g., long-running video analysis) blocks the Brain's responsiveness. Workers move to a second Mac Studio or PC.
3. **Event broker moves off the Brain.** Trigger: high-volume telemetry from many Pis. The broker becomes its own host.
4. **Multi-room Pi expansion.** Each new room is one Pi addition; capacity scales linearly because Pis are independent.

Each migration changes [system-overview.md](system-overview.md) at most; data model and APIs remain stable.

## Design Invariants

- **No device on the network is anonymous.** Even an unprovisioned Pi cannot publish events until pairing completes.
- **Compute is owned, not rented.** Cloud LLMs are reachable via the egress policy ([ai-orchestration.md](ai-orchestration.md)) but no part of the system *requires* cloud to function.
- **The Brain is replaceable.** State lives in Postgres + the durable event log. Rebuilding the Brain on new hardware should be a configuration exercise, not a data-migration one.

## Open Questions

- Do we put Postgres on the Mac mini from day one, or wait for migration trigger? Tracked in [04-roadmap/open-questions.md](../04-roadmap/open-questions.md).
- VPN choice for off-LAN access (Tailscale vs raw WireGuard vs other) — operational concern, deferred until [03-operations/deployment.md](../03-operations/deployment.md) is fleshed out.

# Physical Topology

## Purpose

What hardware plays which role, where it lives, and how it's reached.

## Hardware roles

| Role | Hardware | Notes |
|---|---|---|
| Brain (compute) | Mac Studio, garage | Day-one host for control plane + AI workers. |
| Database | `mac-mini-1` (`mac-mini-m1`) | Day-one Postgres + pgvector host on the LAN. Apple M1, 16 GB unified memory, 512 GB SSD. Current runtime: PostgreSQL `18.4 (Homebrew)` + pgvector `0.8.2`. |
| Static installations | Raspberry Pi + camera + display | One per room, scaling slowly. Run thin perception (face detect, wake word) and avatar UI. |
| Personal mobile | iPhone / iPad | One per family member who uses one. |
| Personal desktop | Laptops, family computer | Web portal access. |
| Future bodies | Robots, farmbot, etc. | HDTS L2/L3 territory; out of day-one scope. |

Hardware inventory is owned by `local-computer-control` at `/Users/timrossi/Desktop/CODE/local-computer-control/inventory.yaml`.

## Network shape

- **LAN-first.** All devices and services normally communicate over the home LAN. The Brain has a stable internal address; clients reach it directly.
- **Off-LAN access via VPN.** Mobile clients away from the house reach the Brain through a wireguard/Tailscale-style mesh. No public-facing endpoints.
- **No untrusted ingress.** Even on-LAN, every connection authenticates per [client-registration.md](../02-domains/client-registration.md).

## Migration paths

The day-one topology is still intentionally small: Brain compute on the Mac Studio, database on `mac-mini-1`, and edge devices as thin clients. Anticipated migrations:

1. **Database moves to larger storage or newer hardware.** Trigger: Postgres latency, SSD pressure, or backup/maintenance windows start hurting interactive latency.
2. **AI/ML workers split across machines.** Trigger: a single workload (e.g., long-running video analysis) blocks the Brain's responsiveness. Workers move to a second Mac Studio or PC.
3. **Event broker moves off the Brain.** Trigger: high-volume telemetry from many Pis. The broker becomes its own host.
4. **Multi-room Pi expansion.** Each new room is one Pi addition; capacity scales linearly because Pis are independent.

Each migration should be an operations/topology change; data model and APIs remain stable.

## Design Invariants

- **No device on the network is anonymous.** Even an unprovisioned Pi cannot publish events until pairing completes.
- **Compute is owned, not rented.** Cloud LLMs are reachable via the egress policy ([ai-orchestration.md](ai-orchestration.md)) but no part of the system *requires* cloud to function.
- **The Brain is replaceable.** State lives in Postgres + the durable event log. Rebuilding the Brain on new hardware should be a configuration exercise, not a data-migration one.

## Open Questions

- VPN choice for off-LAN access (Tailscale vs raw WireGuard vs other) — operational concern, deferred until [03-operations/deployment.md](../03-operations/deployment.md) is fleshed out.

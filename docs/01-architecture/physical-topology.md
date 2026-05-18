# Physical Topology

## Purpose

What hardware plays which role, where it lives, and how it's reached.

## Hardware roles

| Role | Hardware | Notes |
|---|---|---|
| Brain (control plane + agent runtime) | `mac-mini-2` | Day-one host for Phoenix: realtime channels, event routing, identity/capability gates, and the event/idle/maintenance loops. See [ADR-0009](../05-decisions/0009-worker-fleet-topology.md). |
| Web frontend (SvelteKit SSR, prod + dev) | `mac-mini-2` | Co-tenant with the Brain. SvelteKit SSR via `@sveltejs/adapter-node` on Bun, behind one reverse proxy fronting two canonical origins (`i.dinkerwupp.com` prod, `dev.dinkerwupp.com` dev). See [ADR-0010](../05-decisions/0010-web-frontend-hosting.md). |
| Python AI workers | Mac Studio, garage | Day-one host for the FastAPI worker service, Ollama, and AI model runtimes (sync HTTP dispatch per [ADR-0009](../05-decisions/0009-worker-fleet-topology.md)). Likely home for Python workflow workers once [ADR-0006](../05-decisions/0006-workflow-engine.md) closes — workflow placement deferred there. |
| Database | `mac-mini-1` (`mac-mini-m1`) | Day-one Postgres + pgvector host on the LAN. Apple M1, 16 GB unified memory, 512 GB SSD. Current runtime: PostgreSQL `18.4 (Homebrew)` + pgvector `0.8.2`. |
| Static installations | Raspberry Pi + camera + display | One per room, scaling slowly. Run thin perception (face detect, wake word) and avatar UI. |
| Personal mobile | iPhone / iPad | One per family member who uses one. |
| Personal desktop | Laptops, family computer | Web portal access. |
| Future bodies | Robots, farmbot, etc. | HDTS L2/L3 territory; out of day-one scope. |

Hardware inventory is owned by `local-computer-control` at `/Users/timrossi/Desktop/CODE/local-computer-control/inventory.yaml`.

## Network shape

- **LAN-first.** All devices and services normally communicate over the home LAN. The Brain has a stable internal address; clients reach it directly.
- **One canonical origin per environment for the web frontend.** `i.dinkerwupp.com` (prod) and `dev.dinkerwupp.com` (dev) both resolve to `mac-mini-2`'s DHCP-reserved LAN IP (currently `192.168.1.173`) via local DNS overrides or public DNS A-records. HTTPS via DNS-01 ACME on both. See [ADR-0010](../05-decisions/0010-web-frontend-hosting.md).
- **Off-LAN access via VPN.** Mobile clients away from the house reach the Brain through a wireguard/Tailscale-style mesh. No public-facing endpoints.
- **No untrusted ingress.** Even on-LAN, every connection authenticates. Client/device connections authenticate per [client-registration.md](../02-domains/client-registration.md). Internal service-to-service connections (e.g. Brain → worker on the Studio) authenticate per [ADR-0009](../05-decisions/0009-worker-fleet-topology.md) — defense-in-depth: LAN-interface bind, firewall allowlist, and a shared bearer token on every request.

## Migration paths

The day-one topology is still intentionally small: Brain control plane on `mac-mini-2`, Python AI workers on the Mac Studio, database on `mac-mini-1`, and edge devices as thin clients. Anticipated migrations:

1. **Database moves to larger storage or newer hardware.** Trigger: Postgres latency, SSD pressure, or backup/maintenance windows start hurting interactive latency.
2. **Second AI worker host added.** Trigger: sustained AI demand exceeds Studio's throughput, or a second physical location wants its own local worker. Adds an entry to the Brain's routing table; see [ADR-0009](../05-decisions/0009-worker-fleet-topology.md).
3. **Event broker moves off the Brain.** Trigger: high-volume telemetry from many Pis. The broker becomes its own host.
4. **Front door / reverse proxy moves off the Brain.** Trigger: the web frontend grows enough that proxying for it on `mac-mini-2` competes with Phoenix for CPU or interferes with deploys. The reverse proxy becomes its own host; SvelteKit SSR can follow or stay co-located with Phoenix.
5. **Multi-room Pi expansion.** Each new room is one Pi addition; capacity scales linearly because Pis are independent.

Each migration should be an operations/topology change; data model and APIs remain stable.

## Design Invariants

- **No device on the network is anonymous.** Even an unprovisioned Pi cannot publish events until pairing completes.
- **Compute is owned, not rented.** Cloud LLMs are reachable via the egress policy ([ai-orchestration.md](ai-orchestration.md)) but no part of the system *requires* cloud to function.
- **The Brain is replaceable.** State lives in Postgres + the durable event log. Rebuilding the Brain on new hardware should be a configuration exercise, not a data-migration one.
- **The control plane is replaceable independently of the AI tier.** Restarting the Studio for model swaps or upgrades does not drop client sessions or event ingestion. See [ADR-0009](../05-decisions/0009-worker-fleet-topology.md).

## Open Questions

- VPN choice for off-LAN access (Tailscale vs raw WireGuard vs other) — operational concern, deferred until [03-operations/deployment.md](../03-operations/deployment.md) is fleshed out.

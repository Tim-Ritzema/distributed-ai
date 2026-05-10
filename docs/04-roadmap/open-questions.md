# Open Questions

Living list of decisions that need to be made. Each question lives here first; once it's ripe, it gets promoted to an ADR in [05-decisions/](../05-decisions/) and the entry below points to it.

## Active ADRs

- 🟣 [ADR-0001](../05-decisions/0001-control-plane-language.md) — **Control plane language.** Hybrid Elixir/OTP + Python workers leading. Phoenix LiveView excluded. SvelteKit is the UI regardless.
- 🔵 [ADR-0002](../05-decisions/0002-event-broker.md) — **Event broker(s).** Valkey Streams vs NATS JetStream vs Postgres-backed vs MQTT. Likely two brokers, one per plane.
- 🔵 [ADR-0003](../05-decisions/0003-vector-store.md) — **Vector store.** pgvector vs Qdrant.
- 🔵 [ADR-0004](../05-decisions/0004-realtime-transport.md) — **Realtime transport.** Plain WebSockets vs Phoenix Channels for SvelteKit.
- 🟣 [ADR-0005](../05-decisions/0005-device-telemetry-protocol.md) — **Device telemetry protocol.** MQTT favored for Pis.
- 🟣 [ADR-0006](../05-decisions/0006-workflow-engine.md) — **Workflow engine.** Prefect leading.
- 🔵 [ADR-0008](../05-decisions/0008-mobile-push-notifications.md) — **Mobile push transport.** APNS / FCM / OneSignal / self-hosted. Phase 3 concern.

## Accepted

- 🟢 [ADR-0007](../05-decisions/0007-persistent-state-postgres.md) — Postgres for durable app state.

## Pre-ADR questions (not yet ripe)

These are on the radar but don't yet have enough context to write a proper ADR.

- **Postgres on the Mac Studio or on the accompanying Mac mini from day one?** Operational decision; depends on Studio resource headroom. Probably start on the Studio, migrate when contention shows.
- **VPN choice** for off-LAN client access. Tailscale / raw WireGuard / other. Operational; deferred until [03-operations/deployment.md](../03-operations/deployment.md) gets fleshed out.
- **Embedding model.** What runs locally for memory embeddings? Probably one of the small Sentence-Transformers; specific choice pending tests.
- **Topic naming convention.** Provisional: dot-separated lowercase tokens, no underscores. Typically `<domain>.<entity>.<verb>` (e.g., `perception.face.seen`), but `<domain>.<verb>` (`presence.changed`, `job.progress`) and `<domain>.<state>` (`job.succeeded`) are also valid where the entity is implicit. Ratify after first implementation pass. See [01-architecture/event-system.md](../01-architecture/event-system.md).
- **Sensitive-content classifier.** What triggers auto-tightening of memory tiers ([memory-and-context.md](../02-domains/memory-and-context.md))? Probably a small classifier in the Brain on memory creation; tunable.
- **Multi-admin approval** for sensitive grants (e.g., does both parents need to approve `cloud.use[class=health]`?). Today single-parent grants are fine; revisit if needed.
- **Long-term memory consolidation strategy.** After N years, do we summarize and archive? Out of scope for now.
- **Right-to-forget cascade depth.** When Tim deletes a memory, do downstream summaries get rewritten or just flagged with broken provenance?

## How to use this list

- New questions land here when they come up in design conversation.
- Questions get promoted to an ADR (`05-decisions/`) when there are real options to weigh and a near-term need to decide.
- Promoted questions stay in the "Active ADRs" section above until accepted; accepted ADRs move to "Accepted."
- Questions that turn out to be non-decisions (the answer is obvious) get deleted, not closed.

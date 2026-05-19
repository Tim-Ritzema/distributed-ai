# Open Questions

Living list of decisions that need to be made. Each question lives here first; once it's ripe, it gets promoted to an ADR in [05-decisions/](../05-decisions/) and the entry below points to it.

## Active ADRs

- 🟣 [ADR-0002](../05-decisions/0002-event-broker.md) — **Event broker(s).** Staged path leading: Phoenix realtime + Postgres outbox for the spike (Option F), graduate to NATS/JetStream behind the Brain (Option D) when concrete triggers — replay, durable consumers, broker-backed distributed worker queues (beyond [ADR-0009](../05-decisions/0009-worker-fleet-topology.md) sync HTTP dispatch) — are real. Phoenix.PubSub / Phoenix.Channels for connected-client fanout *inside* the Brain; NATS/JetStream as a broker *behind* the Brain.
- 🟣 [ADR-0004](../05-decisions/0004-realtime-transport.md) — **Realtime transport.** Phoenix Channels leading (informed by accepted ADR-0001); plain WebSockets remains the fallback.
- 🟣 [ADR-0005](../05-decisions/0005-device-telemetry-protocol.md) — **Device telemetry protocol.** MQTT favored for Pis.
- 🟣 [ADR-0006](../05-decisions/0006-workflow-engine.md) — **Workflow engine.** Prefect leading for Python AI workflows; Oban now relevant for simple Elixir-side jobs.
- 🔵 [ADR-0008](../05-decisions/0008-mobile-push-notifications.md) — **Mobile push transport.** APNS / FCM / OneSignal / self-hosted. Phase 3 concern.

## Accepted

- 🟢 [ADR-0001](../05-decisions/0001-control-plane-language.md) — Hybrid Elixir/Phoenix control plane + Python AI workers (LiveView excluded; SvelteKit UI).
- 🟢 [ADR-0003](../05-decisions/0003-vector-store.md) — pgvector in Postgres for memory embeddings.
- 🟢 [ADR-0007](../05-decisions/0007-persistent-state-postgres.md) — Postgres for durable app state.
- 🟢 [ADR-0009](../05-decisions/0009-worker-fleet-topology.md) — Worker fleet topology (DB on `mac-mini-1`, Brain on `mac-mini-2`, FastAPI worker service + AI model runtimes on Mac Studio; workflow-worker placement deferred to [ADR-0006](../05-decisions/0006-workflow-engine.md)).
- 🟢 [ADR-0010](../05-decisions/0010-web-frontend-hosting.md) — Web frontend hosting (SvelteKit SSR on `mac-mini-2` via `@sveltejs/adapter-node` on Bun; one canonical origin per environment — `i.dinkerwupp.com` prod, `dev.dinkerwupp.com` dev — with HTTPS via DNS-01 ACME; Phoenix owns `/api/*` and `/socket`; session/cookie mechanism and dev/prod data isolation still deferred inside the ADR with triggers).
- 🟢 [ADR-0011](../05-decisions/0011-reverse-proxy.md) — Reverse proxy on `mac-mini-2` (Caddy v2 with `caddy-dns/cloudflare`; DNS-01 ACME against the Cloudflare-hosted `dinkerwupp.com` zone using a scoped API token; host-header routing into per-environment SvelteKit upstreams on `127.0.0.1`; launchd-supervised).

## Pre-ADR questions (not yet ripe)

These are on the radar but don't yet have enough context to write a proper ADR.

- **VPN choice** for off-LAN client access. Tailscale / raw WireGuard / other. Operational; deferred until [03-operations/deployment.md](../03-operations/deployment.md) gets fleshed out.
- **Dev/prod data isolation** between `i.dinkerwupp.com` and `dev.dinkerwupp.com`. Separate Postgres DB on `mac-mini-1`? Separate schema? Shared DB with a `family-test` Household principal? Deferred inside [ADR-0010](../05-decisions/0010-web-frontend-hosting.md); trigger to close is before dev becomes a real workflow (i.e. before someone runs a destructive migration or seeds test data).
- **Session/cookie mechanism** between browser ↔ SvelteKit SSR ↔ Phoenix. Cookie-forward, internal service credential, or browser-direct. Deferred inside [ADR-0010](../05-decisions/0010-web-frontend-hosting.md); trigger to close is before any capability-gated UI ships. Constrained by ADR-0010's cookie isolation rule (host-only, `HttpOnly` / `Secure` / `SameSite=Lax`) and Phoenix-side CSRF requirement.
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

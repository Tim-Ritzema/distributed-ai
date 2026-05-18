# API and Transport

## Purpose

When to use HTTP, when to use WebSockets, when to use device-telemetry protocols, and when to use mobile push. The default is HTTP — every other choice needs a reason.

## Three transport categories

### HTTP / JSON for CRUD

Use HTTP for any durable, idempotent, request/response operation. This includes:

- Login, logout, session refresh.
- Settings reads and writes.
- Work-item create / update / delete / read ([projects-and-backlog.md](../02-domains/projects-and-backlog.md)).
- Device pairing and registration ([client-registration.md](../02-domains/client-registration.md)).
- Admin approval flows.
- Capability grants and revocations.
- Reading historical events, memories, audit log entries.

HTTP is idempotent, cacheable, easy to test, debuggable with curl, and works through every middlebox. **It is the default.**

### WebSockets for live updates (foreground clients)

Use WebSockets when a client needs **push** from the server while it's active and connected. This includes:

- Assistant token streaming during a chat response.
- Avatar state updates on a static install.
- Room / device events the client cares about (presence, perception, alerts).
- Job progress for a workflow the user is watching.
- Live presence updates across devices.

A WebSocket connection authenticates with a session token derived from the client's device identity. At connect time, the server filters subscribable topics by the client's capability set ([client-registration.md](../02-domains/client-registration.md)).

**Rule: WebSockets are not the default.** Don't reach for them just because something feels live. If a client can poll twice per minute over HTTP and get the same UX, do that instead.

Because [ADR-0001](../05-decisions/0001-control-plane-language.md) accepted Elixir/Phoenix for the control plane, [ADR-0004](../05-decisions/0004-realtime-transport.md) now proposes **Phoenix Channels** as the realtime transport for SvelteKit clients; **plain WebSockets** remain the fallback. **Phoenix LiveView is explicitly excluded** — the UI runs on SvelteKit regardless.

### Route ownership on the canonical origin

Per [ADR-0010](../05-decisions/0010-web-frontend-hosting.md), browser clients reach the household app through one canonical origin per environment (`i.dinkerwupp.com` prod, `dev.dinkerwupp.com` dev), fronted by a reverse proxy on `mac-mini-2`. **SvelteKit SSR owns human-facing page routes** (`/`, `/chat`, `/memories`, `/projects`, `/devices`, `/settings`, `/login`, `/pair`, `/avatar/*`, `/admin/*`, framework assets). **Phoenix owns `/api/*`** (including all auth endpoints under `/api/auth/*`) **and `/socket`**. SvelteKit does not expose a stable public system API via `+server.ts`; durable business logic and capability enforcement live in Phoenix. The transport rules above are unchanged — this is route ownership, not new transport.

### Device telemetry (Pis / IoT)

Pis publishing high-volume perception or sensor data probably want a purpose-built telemetry protocol rather than HTTP or WebSockets. **MQTT is favored** ([ADR-0005](../05-decisions/0005-device-telemetry-protocol.md)) for QoS levels, lossy-network resilience, and low overhead, but the decision isn't final.

Whatever wins, the device telemetry plane is **separate** from the realtime UI plane (see [system-planes.md](system-planes.md)).

### Mobile push (background / closed clients)

Foreground mobile clients receive live updates over WebSocket. **Backgrounded or closed mobile clients need APNS / FCM-style push notifications** to receive proactive alerts (a job finished, a family member needs attention, a security event).

Push is **complementary** to WebSockets, not a replacement. The flow is typically:

1. The Brain decides a backgrounded client needs to know something.
2. The Brain sends a push via the chosen provider.
3. The push wakes the app.
4. The app reconnects its WebSocket and receives the full live stream.

Provider choice (APNS direct, FCM, OneSignal, self-hosted webpush) is deferred to [ADR-0008](../05-decisions/0008-mobile-push-notifications.md). Not needed until Phase 3 ([phases.md](../04-roadmap/phases.md)).

## Design Invariants

- **HTTP is the default.** Every other transport requires a reason.
- **No transport bypasses capability checks.** WebSocket subscribe filters, HTTP authorization headers, MQTT topic ACLs, and push targeting all enforce the same capability model.
- **The same data is reachable through multiple transports.** A work item's progress is queryable over HTTP and pushable over WebSocket. The client picks the transport that fits.
- **Phoenix LiveView is excluded.** UI rendering is the SvelteKit client's job.

## Open Questions

- 🟢 [ADR-0001](../05-decisions/0001-control-plane-language.md) — control plane language: Elixir/Phoenix accepted.
- 🟣 [ADR-0004](../05-decisions/0004-realtime-transport.md) — plain WebSockets vs Phoenix Channels for SvelteKit (Phoenix Channels leading).
- 🟣 [ADR-0005](../05-decisions/0005-device-telemetry-protocol.md) — MQTT vs WebSockets vs HTTP polling for Pis.
- 🔵 [ADR-0008](../05-decisions/0008-mobile-push-notifications.md) — push provider for backgrounded mobile clients.

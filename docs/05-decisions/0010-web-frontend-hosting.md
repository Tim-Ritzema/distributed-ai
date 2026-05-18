# ADR-0010: Web frontend hosting

**Status:** 🟢 accepted (SvelteKit SSR on `mac-mini-2` via `@sveltejs/adapter-node` on Bun; HTTPS via DNS-01 ACME for both `i.dinkerwupp.com` and `dev.dinkerwupp.com`; Phoenix owns `/api/*` and `/socket`; reverse-proxy software, session mechanism, and dev/prod data isolation deferred)

## Context

[ADR-0001](0001-control-plane-language.md) accepted SvelteKit as the web UI and explicitly excluded Phoenix LiveView, but left open *where the SvelteKit runtime lives* and *how the front door is shaped*. [ADR-0009](0009-worker-fleet-topology.md) pinned the Phoenix Brain to `mac-mini-2` and made reliability isolation a first-class concern: Studio reboots, model swaps, and Python worker faults must not drop client sessions. [ADR-0004](0004-realtime-transport.md) leans toward Phoenix Channels as the realtime transport for SvelteKit clients. [api-and-transport.md](../01-architecture/api-and-transport.md) sets HTTP as the default and Phoenix Channels (over WebSocket) as the live-update transport.

What is left unspecified is the host placement of the SvelteKit runtime itself, the route ownership boundary between SvelteKit and Phoenix on the family-facing origin, and the operational shape of the front door. Two things make this urgent:

- The Pre-Phase 0 Phoenix spike ([phases.md](../04-roadmap/phases.md)) will push one server event to a SvelteKit client. There needs to be a SvelteKit runtime *somewhere* before that line of code can run end-to-end.
- The family-facing web UI is the most visible reliability surface. If it goes down when the Studio reboots, the household experience is "the system is broken," even though the Brain and DB are fine.

This ADR closes host placement, route ownership, runtime shape, and the front-door environments. It defers the choice of reverse-proxy software, the exact session/cookie mechanism, and dev/prod data isolation — each with a trigger to close.

## Options

### Option A — SvelteKit SSR on `mac-mini-2`, one canonical origin per environment *(selected)*

SvelteKit SSR runs on `mac-mini-2` alongside the Phoenix Brain, behind a reverse proxy that owns the canonical web origin for each environment. SvelteKit owns human-facing page routes; Phoenix owns `/api/*` and `/socket`; the Studio remains internal-only.

- **Pros:**
  - Web UI stays up when the Studio reboots, swaps models, or experiences Python/Ollama faults.
  - Same-origin routing — cookies, CSRF, CORS, and WebSocket origin checks all simplify.
  - `mac-mini-1` stays a boring state appliance for Postgres + pgvector.
  - Studio stays a restartable worker/model-runtime box, not the family-facing front door.
  - Hardware roles match form factors: minis as always-on appliances, Studio as the GPU/inference box.
- **Cons:**
  - Adds Node/Bun runtime to the Brain host (one more process tree to supervise).
  - Requires a reverse-proxy front door on `mac-mini-2`.

### Option B — Static SvelteKit build on `mac-mini-2`

`@sveltejs/adapter-static` only; no SSR process.

- **Pros:**
  - Simpler runtime (no Node/Bun on the Brain host).
- **Cons:**
  - No server-side rendering for authenticated pages or form actions.
  - Pushes auth-aware rendering and OAuth callback handling into the client, which the [service boundary](#service-boundary) rejects.
  - Premature optimization for "no Node" given Phase 0 actually wants an SSR shell.

### Option C — SvelteKit on Mac Studio

Co-locate the UI with Python workers.

- **Pros:**
  - One fewer service on the Brain host.
- **Cons:**
  - Bad availability coupling: Studio reboots and model work take the family-facing UI down.
  - Directly contradicts [ADR-0009](0009-worker-fleet-topology.md)'s reliability-isolation direction.
  - Makes the worker box family-facing — wrong posture for an always-on web origin.

### Option D — SvelteKit on `mac-mini-1`

Co-locate the UI with Postgres.

- **Pros:**
  - Keeps the web UI away from Brain CPU.
- **Cons:**
  - Pollutes the Postgres appliance with app/web runtime.
  - Weakens the "source-of-truth box runs no third-party code" posture from [ADR-0007](0007-persistent-state-postgres.md) and [ADR-0009](0009-worker-fleet-topology.md).
  - Couples web deploys to the database host.

## Decision

**Option A — SvelteKit SSR on `mac-mini-2`, one canonical origin per environment.**

### Route ownership

- **SvelteKit SSR (UI pages):** `/`, `/chat`, `/memories`, `/projects`, `/devices`, `/settings`, `/login`, `/pair`, `/avatar`, `/avatar/*`, `/admin`, `/admin/*`, and the framework asset namespace `/_app/*`. Admin and avatar are UI surfaces only — no privileged decisions live there.
- **Phoenix HTTP API:** all of `/api/*`.
- **Phoenix Channels:** `/socket` (per [ADR-0004](0004-realtime-transport.md)'s leading recommendation).
- **Health endpoints:** `/health` is the reverse-proxy front-door health check, unauthenticated; it returns 200 only when the proxy is up *and* the SvelteKit SSR upstream is reachable. The proxy maps the public `/health` to an internal SvelteKit-only health route such as `/_health` (a `+server.ts` returning 200 if the SSR process is alive); `/_health` is not exposed as a browser route. The SvelteKit SSR process binds to `127.0.0.1` only — never the LAN interface — so `/_health` and every other internal SvelteKit route is reachable solely through the reverse proxy. `/api/health` is Phoenix liveness, unauthenticated (or network-local if firewall scoping is added), and does not depend on SvelteKit. `/api/session` is Phoenix's authenticated user/session check.
- Browser code uses relative URLs (`/api/...`, `/socket`); never hardcoded hostnames.

### Auth and privileged surfaces

SvelteKit owns `/login`, `/avatar/*`, and `/admin/*` as UI routes only. Phoenix owns all authentication, session, capability, and mutation endpoints under `/api/*`. Specifically: `/api/auth/login` (email/password), `/api/auth/logout`, `/api/auth/session`, `/api/auth/google/start`, `/api/auth/google/callback`. Admin pages render in SvelteKit; all privileged decisions, credential verification, and OAuth callbacks land in Phoenix. SvelteKit never inspects or bypasses capability rules. Google OAuth `state` and nonce generation/validation live in Phoenix.

**Cookie isolation rule** (binding constraint on the deferred session mechanism): session cookies are host-only — the `Domain` attribute is *never* set — so `i.dinkerwupp.com` and `dev.dinkerwupp.com` sessions cannot bleed across subdomains. Defaults: `HttpOnly`, `Secure`, `SameSite=Lax` unless a later auth flow forces a tighter or looser setting and documents why. Google OAuth's top-level-redirect callback flow is expected to work with `SameSite=Lax`; only POST-based callbacks or embedded flows would force revisiting this.

### Service boundary

SvelteKit is presentation only: no direct Postgres reads, no direct Studio worker calls, no stable public system API exposed via `+server.ts`. SvelteKit may use server-side `load` functions and form actions, but those call Phoenix; durable business logic lives in Phoenix. Studio FastAPI stays internal-only per [ADR-0009](0009-worker-fleet-topology.md) — Phoenix is the only caller.

Env-var convention: `PUBLIC_*` is browser-visible; `$env/static/private` is for server-only values fixed at build time; `$env/dynamic/private` is for runtime secrets and config provisioned by launchd (the common case for credentials).

### SvelteKit runtime shape

- **Build target:** `@sveltejs/adapter-node`. Option B's `adapter-static` is rejected; the community `svelte-adapter-bun` is not chosen — keep the official adapter so the SvelteKit upgrade path stays boring.
- **Build command:** `pnpm build`. pnpm is the package manager (deterministic lockfile, broad npm ecosystem compat).
- **Production runtime:** **Bun** running the `adapter-node` build output. Apple-Silicon-native, fast cold-start; Bun's Node-API compat carries the adapter-node server.
- **Fallback:** plain Node LTS, swapping only the launchd binary path. Trigger to fall back: a persistent `adapter-node`-on-Bun compatibility bug that blocks shipping.
- **Process supervision:** launchd, owned by `local-computer-control`, matching the Phoenix and Postgres pattern on the rest of the fleet. The plist invokes `bun ./build/index.js` (the `adapter-node` entrypoint; the fallback Node command is `node ./build/index.js`).

### Single-origin implications

These follow directly from the same-origin design and are decided here, not deferred:

- **CORS:** none required in Phase 0.
- **CSRF (SvelteKit form actions):** SvelteKit's built-in `csrf.checkOrigin` stays enabled with default settings.
- **CSRF (Phoenix `/api/*` mutations):** any cookie-backed mutation on `/api/*` requires Phoenix-side CSRF protection. The exact mechanism (synchronizer token, double-submit, `SameSite=Strict` on a separate CSRF cookie, header-based for fetch-from-same-origin) closes with the deferred session/cookie decision; the *requirement* is decided here.
- **WebSocket upgrade:** the reverse proxy must support HTTP/1.1 upgrade on `/socket`. Rules out static-file-only proxies; Caddy, nginx, and Traefik all qualify.
- **Phoenix `check_origin`:** allow the full origins `https://i.dinkerwupp.com`, `https://dev.dinkerwupp.com`, and any temporary local origins (`http://192.168.1.173`, `http://mac-mini-2.local`) used during the spike.

### Environments

- **Production:** `https://i.dinkerwupp.com` → `mac-mini-2`.
- **Development:** `https://dev.dinkerwupp.com` → `mac-mini-2`.
- Both hostnames terminate at the same reverse proxy on `mac-mini-2`, which routes by `Host` header. **Runtime isolation:** a separate SvelteKit launchd service (with its own env and port) per environment is decided here — prod and dev SvelteKit never share a process. Whether Phoenix runs as one shared process or two per-environment processes is part of the deferred dev/prod data isolation decision.
- **Addressing:** `mac-mini-2` holds a stable LAN address via a router DHCP reservation (currently `192.168.1.173`). `i.dinkerwupp.com` and `dev.dinkerwupp.com` resolve to that IP via either local DNS overrides (router / Pi-hole / hosts file) or public DNS A-records pointing at the private IP. Public-DNS-to-private-IP records may be blocked by router DNS-rebind protection on some networks; if that bites in practice, fall back to local DNS overrides for on-LAN clients.
- **`home.dinkerwupp.com`** stays where it is — the avatar-lab prototype on S3/CloudFront ([`prototypes/avatar-lab/`](../../prototypes/avatar-lab/)). It is not moved onto `mac-mini-2` by this ADR.

### TLS / HTTPS

**HTTPS via DNS-01 ACME for both hostnames is Phase 0**, not deferred. Google OAuth callbacks, `Secure` cookies for sessions, and browser secure-context APIs (camera / mic for the avatar surface) all require HTTPS; the cost of deferring is greater than the cost of building it in from the start. ACME DNS-01 issuance against the public DNS zone provisions trusted certs without exposing `mac-mini-2` to the public internet. Cert provisioning runs from the reverse proxy on `mac-mini-2`; the ACME client is bundled into the reverse-proxy selection — Caddy has built-in ACME support but DNS-01 still requires the appropriate DNS provider module; nginx needs an external client such as `acme.sh` or `lego`. Public-facing HTTPS ingress, mTLS for service-to-service, and harder TLS policy (HSTS preload, key pinning) remain deferred.

### Deferred

Closed inside this ADR with triggers, not in separate ADRs unless they grow:

- **Reverse-proxy software** (Caddy / nginx / Traefik / Apple's built-in nginx fork). Trigger to close: before the Pre-Phase 0 spike serves a SvelteKit page through the front door. Choice constrains the ACME client (see TLS subsection).
- **Session/cookie mechanism** between browser ↔ SvelteKit SSR ↔ Phoenix (cookie-forward, internal service credential, browser-direct). Trigger to close: before any capability-gated UI ships.
- **CSP (Content Security Policy).** Defer until mobile or external clients reach the front door.
- **Dev/prod data isolation.** Trigger to close: before dev becomes a real workflow (i.e. before someone runs a destructive migration or seeds test data).
- **Public ingress, mTLS, harder TLS policy.** Deferred per the TLS subsection above; triggers are off-LAN ingress without VPN, multi-host service mesh, or compliance requirements.

## Consequences

- [`01-architecture/physical-topology.md`](../01-architecture/physical-topology.md) hardware-roles table gains a "Web frontend (SvelteKit SSR, prod + dev environments)" row pinned to `mac-mini-2`. Migration paths gain a "front door / reverse proxy moves off the Brain" item. Network shape notes that the two canonical origins resolve to `mac-mini-2`'s DHCP-reserved LAN IP via local DNS overrides or public DNS records.
- [`03-operations/deployment.md`](../03-operations/deployment.md) gains a "Current Web Frontend Host" section: SvelteKit SSR on `mac-mini-2` built with `pnpm build` against `@sveltejs/adapter-node`, running on Bun under launchd (fallback Node LTS); two named environments behind a single reverse proxy on `mac-mini-2` with HTTPS via DNS-01 ACME; `/health` owned by the reverse proxy, `/api/health` and `/api/session` owned by Phoenix; reverse-proxy software, session mechanism, and dev/prod data isolation explicitly deferred. The existing `prototypes/avatar-lab/` `home.dinkerwupp.com` S3 deploy is cross-referenced as independent of the assistant front door. `local-computer-control` provisioning gains: install Bun and pnpm on `mac-mini-2`; create DNS records for both hostnames; provision ACME credentials for the public DNS zone.
- [`04-roadmap/phases.md`](../04-roadmap/phases.md) Phase 0 "In scope" gains "SvelteKit SSR web client on `mac-mini-2` behind one canonical origin per environment." Pre-Phase 0 spike gains a line: one SvelteKit SSR page served through the front door at `/`, alongside Phoenix at `/api/health` and `/socket`.
- [`01-architecture/api-and-transport.md`](../01-architecture/api-and-transport.md) gains a short paragraph on route ownership: `/api/*` and `/socket` are Phoenix's; page routes are SvelteKit SSR's; same canonical origin per environment. No transport rules change.
- [`docs/README.md`](../README.md) accepted-decisions table gains a new row for ADR-0010; the prose summary adds "web frontend hosting" to the list of accepted technology choices; the ADR index entry is marked accepted.
- [`04-roadmap/open-questions.md`](../04-roadmap/open-questions.md) moves ADR-0010 to "Accepted" and adds dev/prod data isolation as a pre-ADR question linked back to this ADR's deferred block.
- Google OAuth: both callback URLs (`https://i.dinkerwupp.com/api/auth/google/callback` and `https://dev.dinkerwupp.com/api/auth/google/callback`) must be registered in the Google Cloud OAuth client. Registration is an operational step owned by the account holder, tracked in `deployment.md` once the Google client is provisioned.
- Reliability posture: Studio reboots leave the web UI up. The Postgres host stays code-free. The web UI and Brain share a host but operate in independent process trees. Dev and prod share a host and a reverse proxy; isolation specifics deferred.

## References

- [ADR-0001](0001-control-plane-language.md) — control plane language; chose SvelteKit as the UI and excluded LiveView. This ADR specifies host placement and front-door shape.
- [ADR-0004](0004-realtime-transport.md) — realtime transport; Phoenix Channels leading. This ADR pins `/socket` ownership to Phoenix.
- [ADR-0007](0007-persistent-state-postgres.md) — Postgres on `mac-mini-1`; unchanged. This ADR keeps `mac-mini-1` code-free.
- [ADR-0009](0009-worker-fleet-topology.md) — three-host worker fleet topology. This ADR extends the reliability-isolation posture to the web frontend.
- [01-architecture/physical-topology.md](../01-architecture/physical-topology.md) — hardware-roles table and migration paths updated by this decision.
- [01-architecture/api-and-transport.md](../01-architecture/api-and-transport.md) — route ownership note added by this decision.
- [03-operations/deployment.md](../03-operations/deployment.md) — Current Web Frontend Host section added by this decision.
- [04-roadmap/phases.md](../04-roadmap/phases.md) — Phase 0 scope and Pre-Phase 0 spike updated.

# Deployment 🟡

## Repo Boundary

`distributed-ai` owns the application: Brain, workers, clients, prototypes, docs, and app-level deployment assets.

`local-computer-control` owns the fleet control layer: host inventory, SSH credentials, key bootstrap, OS/package setup, system services, and repeatable scripts for preparing machines to run the app.

Put another way: `distributed-ai` defines what runs; `local-computer-control` prepares where it runs.

## Current Prototype

The Wubblefazz avatar/perception prototype now lives at `prototypes/avatar-lab/`. It includes the static browser client and the S3/CloudFront deployment script for `home.dinkerwupp.com`.

The Pi kiosk setup remains in `local-computer-control` because it configures a physical host to open that deployed URL.

## Current Database Host

`mac-mini-1` is the day-one database host for Postgres and pgvector. Fleet identity and hardware details live in `/Users/timrossi/Desktop/CODE/local-computer-control/inventory.yaml`:

- Host: `mac-mini-1` / `mac-mini-m1` on the home LAN.
- Hardware: Macmini9,1; Apple M1 (8 cores); 16 GB unified memory; 512 GB Apple SSD.
- Runtime: PostgreSQL `18.4 (Homebrew)` via Homebrew `postgresql@18`.
- Extension: pgvector `0.8.2`.

`local-computer-control` owns machine preparation, package installation, launchd service setup, firewall/power settings, and secrets. The relevant provisioning script is `/Users/timrossi/Desktop/CODE/local-computer-control/scripts/device/mac-mini-1/install-postgres.sh`.

`distributed-ai` owns schema design, migrations, application-level database access, and backup/restore expectations for this app.

## Current Brain Host

`mac-mini-2` is the day-one host for the Phoenix Brain (control plane + agent runtime) per [ADR-0009](../05-decisions/0009-worker-fleet-topology.md). Hardware specifics and provisioning live in `local-computer-control`'s `inventory.yaml`; service installation, BEAM runtime, and launchd setup are owned there.

`distributed-ai` owns the Phoenix application source, configuration shape, schema migrations against `mac-mini-1`, and Channel / event-router code.

## Current Worker Host

The Mac Studio (garage) is the day-one host for the Python AI worker tier per [ADR-0009](../05-decisions/0009-worker-fleet-topology.md). It runs the FastAPI worker service, Ollama, and local model runtimes (transcription, embeddings, vision, OCR, LLM inference). Python workflow workers are the likely next addition here once [ADR-0006](../05-decisions/0006-workflow-engine.md) closes, but their placement is ADR-0006's decision — not ADR-0009's.

`local-computer-control` owns machine preparation, Python environment, model installation, and service supervision. `distributed-ai` owns the FastAPI application source, endpoint contracts, and the routing table the Brain uses to dispatch tasks.

Worker service auth follows the **defense-in-depth** rule defined in [ADR-0009](../05-decisions/0009-worker-fleet-topology.md): the Studio FastAPI binds to the LAN interface (not WAN), the host firewall allowlists `mac-mini-2`'s LAN IP as the only inbound source, and every request requires `Authorization: Bearer <token>` (the actual auth gate — interface bind and firewall are belt-and-suspenders, not access control). The bearer token is provisioned out-of-band via env vars (owned by `local-computer-control`); `distributed-ai` owns token verification.

TLS is not required in Phase 0. The token travels in cleartext over the LAN, which assumes the LAN is trusted at the confidentiality layer. mTLS, per-task tokens, and TLS itself are deferred until (a) a remote worker host is added, (b) worker traffic crosses an untrusted network, or (c) the LAN's confidentiality assumption stops holding (guest segments, etc.). See ADR-0009 for the canonical rationale and deferred-item triggers.

## Current Web Frontend Host

`mac-mini-2` is also the day-one host for the SvelteKit web frontend per [ADR-0010](../05-decisions/0010-web-frontend-hosting.md). It runs co-tenant with the Phoenix Brain. Build, runtime, and supervision:

- Build target: [`@sveltejs/adapter-node`](https://kit.svelte.dev/docs/adapter-node) (`adapter-static` rejected; the community `svelte-adapter-bun` is not used).
- Build command: `pnpm build`.
- Production runtime: **Bun** running `bun ./build/index.js` (the adapter-node entrypoint).
- Fallback runtime: Node LTS via `node ./build/index.js` — swap only the launchd binary path. Trigger: a persistent adapter-node-on-Bun compatibility bug that blocks shipping.
- Process supervision: launchd, owned by `local-computer-control`. A separate launchd service per environment — prod and dev SvelteKit never share a process.
- Binding: SvelteKit SSR listens on `127.0.0.1` only, never the LAN interface. Reachable only through the reverse proxy.

Two named environments behind a single reverse proxy on `mac-mini-2`:

- Production: `https://i.dinkerwupp.com`.
- Development: `https://dev.dinkerwupp.com`.

**Upstream port convention** (referenced from [ADR-0011](../05-decisions/0011-reverse-proxy.md) — the Caddyfile and per-environment launchd plists must agree on these):

| Upstream | Bind | Launchd / runtime contract |
|---|---|---|
| SvelteKit prod | `127.0.0.1:3000` | `HOST=127.0.0.1 PORT=3000` in the prod launchd plist's `EnvironmentVariables`. **Both `HOST` and `PORT` are required** — `adapter-node` defaults `HOST` to `0.0.0.0`, so omitting it would bind the LAN interface and contradict ADR-0010's loopback-only rule. |
| SvelteKit dev | `127.0.0.1:3001` | `HOST=127.0.0.1 PORT=3001` in the dev launchd plist's `EnvironmentVariables`. Same `HOST` requirement applies. |
| Phoenix | `127.0.0.1:4000` | Phoenix is configured to bind `127.0.0.1:4000` in `config/runtime.exs` (`http: [ip: {127, 0, 0, 1}, port: 4000]`) — not via env var. **Single shared process today** — both `i.` and `dev.` Host-header routes proxy `/api/*` and `/socket` here. Whether Phoenix splits into per-environment processes (on, e.g., `:4000` and `:4001`) is part of ADR-0010's deferred dev/prod data isolation decision; the Caddyfile changes when that closes. |

Phoenix and SvelteKit both bind `127.0.0.1` only — they are not reachable except through Caddy. `local-computer-control` is responsible for setting `HOST` and `PORT` in each SvelteKit plist; `distributed-ai` is responsible for keeping Phoenix's bind config pointed at `127.0.0.1`.

Both hostnames resolve to `mac-mini-2`'s DHCP-reserved LAN IP (currently `192.168.1.173`) via local DNS overrides (router / Pi-hole / hosts file) or public DNS A-records pointing at the private IP. Public-DNS-to-private-IP records can be blocked by router DNS-rebind protection; if that bites, fall back to local DNS overrides for on-LAN clients.

HTTPS via DNS-01 ACME is required from day one — Google OAuth callbacks, `Secure` session cookies, and browser secure-context APIs (camera / mic for the avatar surface) all need it. The reverse proxy is **Caddy v2 with the `caddy-dns/cloudflare` module**, supervised by launchd, per [ADR-0011](../05-decisions/0011-reverse-proxy.md). Cert issuance and renewal run from Caddy using DNS-01 against the Cloudflare-hosted `dinkerwupp.com` zone. The Cloudflare API token Caddy uses is a **separate, scoped token** (`Zone:DNS:Edit` + `Zone:Zone:Read`, restricted to `dinkerwupp.com`), never the broader token in `distributed-ai/.env`. See [caddy.md](caddy.md) for the setup and validation runbook.

Health endpoints:

- `/health` → reverse-proxy front-door, unauthenticated. Proxied through to an internal SvelteKit `/_health` route that returns 200 if the SSR process is alive. `/_health` is not exposed as a browser route.
- `/api/health` → Phoenix liveness, unauthenticated (or network-local), does not depend on SvelteKit.
- `/api/session` → Phoenix authenticated session check.

Auth routes: Phoenix owns all of `/api/auth/*` including email/password login, OAuth `start` / `callback`, session, and logout. Google OAuth callbacks `https://i.dinkerwupp.com/api/auth/google/callback` and `https://dev.dinkerwupp.com/api/auth/google/callback` must both be registered in the Google Cloud OAuth client; registration is owned by the account holder.

`local-computer-control` owns: installing Bun and pnpm on `mac-mini-2`; installing Caddy v2 with the `caddy-dns/cloudflare` module compiled in (vanilla `brew install caddy` is insufficient — it ships without DNS provider modules; use `xcaddy build` or pull a known-good build that bundles the module); provisioning launchd services for the SvelteKit prod and dev runtimes plus Caddy; creating DNS records (or local DNS overrides) for both hostnames; provisioning a scoped Cloudflare API token for Caddy at a read-protected path consumed by the Caddy launchd plist (not in `distributed-ai/.env`); configuring firewall rules to expose only `:80` (redirect to `:443`) and `:443` on the LAN interface. `distributed-ai` owns the SvelteKit application source, route ownership, environment-variable convention (`PUBLIC_*` browser-visible, `$env/static/private` build-time-fixed, `$env/dynamic/private` for launchd-provisioned runtime secrets), the Caddyfile source, and the contract with Phoenix `/api/*` and `/socket`.

The existing `prototypes/avatar-lab/` `home.dinkerwupp.com` S3/CloudFront deploy is independent of the assistant front door and is not moved to `mac-mini-2` by ADR-0010.

Deferred (with triggers in ADR-0010): session/cookie mechanism, CSP, dev/prod data isolation, public ingress + mTLS + harder TLS policy.

## Secrets

AWS credentials for the prototype deploy live in `distributed-ai/.env`, which is gitignored. `distributed-ai/.env.example` documents the expected variable names.

Remaining broker topology, plus any service definitions and network setup not already covered by [ADR-0009](../05-decisions/0009-worker-fleet-topology.md), will firm up after [ADR-0002](../05-decisions/0002-event-broker.md) closes.

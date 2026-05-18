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

Both hostnames resolve to `mac-mini-2`'s DHCP-reserved LAN IP (currently `192.168.1.173`) via local DNS overrides (router / Pi-hole / hosts file) or public DNS A-records pointing at the private IP. Public-DNS-to-private-IP records can be blocked by router DNS-rebind protection; if that bites, fall back to local DNS overrides for on-LAN clients.

HTTPS via DNS-01 ACME is required from day one — Google OAuth callbacks, `Secure` session cookies, and browser secure-context APIs (camera / mic for the avatar surface) all need it. Cert provisioning runs from the reverse proxy on `mac-mini-2`. The reverse-proxy software is deferred (Caddy / nginx / Traefik); whatever wins must support DNS-01 ACME and HTTP/1.1 upgrade for `/socket`.

Health endpoints:

- `/health` → reverse-proxy front-door, unauthenticated. Proxied through to an internal SvelteKit `/_health` route that returns 200 if the SSR process is alive. `/_health` is not exposed as a browser route.
- `/api/health` → Phoenix liveness, unauthenticated (or network-local), does not depend on SvelteKit.
- `/api/session` → Phoenix authenticated session check.

Auth routes: Phoenix owns all of `/api/auth/*` including email/password login, OAuth `start` / `callback`, session, and logout. Google OAuth callbacks `https://i.dinkerwupp.com/api/auth/google/callback` and `https://dev.dinkerwupp.com/api/auth/google/callback` must both be registered in the Google Cloud OAuth client; registration is owned by the account holder.

`local-computer-control` owns: installing Bun and pnpm on `mac-mini-2`; provisioning launchd services for the SvelteKit prod and dev runtimes plus the reverse proxy; creating DNS records (or local DNS overrides) for both hostnames; provisioning ACME credentials for the public DNS zone. `distributed-ai` owns the SvelteKit application source, route ownership, environment-variable convention (`PUBLIC_*` browser-visible, `$env/static/private` build-time-fixed, `$env/dynamic/private` for launchd-provisioned runtime secrets), and the contract with Phoenix `/api/*` and `/socket`.

The existing `prototypes/avatar-lab/` `home.dinkerwupp.com` S3/CloudFront deploy is independent of the assistant front door and is not moved to `mac-mini-2` by ADR-0010.

Deferred (with triggers in ADR-0010): reverse-proxy software choice, session/cookie mechanism, CSP, dev/prod data isolation, public ingress + mTLS + harder TLS policy.

## Secrets

AWS credentials for the prototype deploy live in `distributed-ai/.env`, which is gitignored. `distributed-ai/.env.example` documents the expected variable names.

Remaining broker topology, plus any service definitions and network setup not already covered by [ADR-0009](../05-decisions/0009-worker-fleet-topology.md), will firm up after [ADR-0002](../05-decisions/0002-event-broker.md) closes.

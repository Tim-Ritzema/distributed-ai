# ADR-0011: Reverse proxy on `mac-mini-2`

**Status:** 🟢 accepted (Caddy v2 on `mac-mini-2` with the `caddy-dns/cloudflare` module; DNS-01 ACME against the Cloudflare-hosted `dinkerwupp.com` zone using a scoped Cloudflare API token; host-header routing into per-environment SvelteKit upstreams on `127.0.0.1`; launchd-supervised)

## Context

[ADR-0010](0010-web-frontend-hosting.md) accepted SvelteKit SSR on `mac-mini-2` behind a single reverse proxy fronting `i.dinkerwupp.com` (prod) and `dev.dinkerwupp.com` (dev), with HTTPS via DNS-01 ACME from day one. It deferred the choice of reverse-proxy software with the trigger "before the Pre-Phase 0 spike serves a SvelteKit page through the front door." The trigger is now active: the Pre-Phase 0 spike per [phases.md](../04-roadmap/phases.md) is imminent, and DNS for both hostnames is already provisioned (Cloudflare is the DNS host for `dinkerwupp.com`; A-records for `i` and `dev` point to `mac-mini-2`'s LAN IP `192.168.1.173`).

The choice is constrained by prior decisions:

- **WebSocket upgrade on `/socket`** ([ADR-0010:104](0010-web-frontend-hosting.md)) — rules out static-only proxies.
- **DNS-01 ACME** for both hostnames ([ADR-0010:117](0010-web-frontend-hosting.md)) — the ACME client must support Cloudflare's API. Caddy needs a DNS provider module; nginx needs an external client.
- **Host-header routing** into two SvelteKit upstreams bound to `127.0.0.1` ([ADR-0010:111](0010-web-frontend-hosting.md), [ADR-0010:74](0010-web-frontend-hosting.md)) — every internal SvelteKit route, including `/_health`, is reachable only through the proxy.
- **Threat model is LAN-local.** `mac-mini-2` is on a private LAN IP with no public ingress; public-internet exposure is explicitly out of scope until the deferred "public ingress + mTLS + harder TLS policy" item in ADR-0010 closes. Compromise vectors are misconfigured TLS and LAN-resident devices, not internet-facing exploitation.

## Options

### Option A — Caddy v2 *(selected)*

Single Go binary with built-in ACME. The `caddy-dns/cloudflare` module is compiled into the Caddy binary via `xcaddy build` (or pulled from a distribution that bundles it) — Caddy does not load DNS provider modules at runtime — providing DNS-01 against Cloudflare.

- **Pros:**
  - Built-in ACME — no separate cert client to supervise.
  - Memory-safe Go runtime; structurally immune to the buffer-overflow CVE class that has produced nginx's worst historical bugs.
  - Safer defaults out of the box: TLS 1.2+, modern cipher suites, automatic HTTPS redirect from `:80` to `:443`. HSTS is not added by default; this ADR requires it as an explicit Caddyfile directive (see TLS section below).
  - Caddyfile config for this footprint is ~15 lines and difficult to misconfigure into an insecure TLS posture.
  - One process under launchd. Restart-on-edit semantics make ops trivial.
- **Cons:**
  - Younger than nginx (~10 years vs 21); smaller deployment base; less accumulated scar tissue.
  - Concentrated maintainer/sponsor (Stack Holdings). Single-sponsor risk is real but mitigated by Go memory safety and a 10-year track record at scale (Stripe, Hugging Face, others).
  - Plugin model means the binary that runs in production is not the off-the-shelf release — provisioning has to build (or pull a built image of) Caddy-with-cloudflare-module rather than `brew install caddy`.

### Option B — nginx

C HTTP server with external ACME client (`acme.sh` or `lego`) for DNS-01.

- **Pros:**
  - 21 years of public-facing scrutiny; massive deployment base (~30% of all websites); fastest CVE disclosure feedback loop of any web server.
  - Multiple independent forks (OpenResty, Angie, freenginx) have audited the codebase from different angles.
  - More household-name admins know nginx config than Caddyfile.
- **Cons:**
  - Memory-safety CVE class still present by construction (written in C).
  - Two processes to supervise (nginx + ACME client) instead of one.
  - Larger config surface; easier to misconfigure TLS than Caddy.
  - Upstream governance is currently contested — Maxim Dounin's February 2024 fork to **freenginx** was driven by disagreement with F5 over CVE disclosure policy for experimental QUIC code. Not fatal, but the "mature upstream" story is more nuanced than it was pre-2024.
  - The security-maturity advantage matters most at internet scale; for a LAN-only front door with no public ingress, the operational simplicity of Caddy is the bigger real-world security input.

### Option C — Traefik

Go HTTP proxy with built-in ACME and Cloudflare provider.

- **Pros:**
  - Native DNS-01 ACME with Cloudflare provider.
  - Declarative routing config.
- **Cons:**
  - Designed for container orchestration and service discovery; the operational model doesn't fit a launchd-supervised single host.
  - Significantly larger surface than warranted for two upstreams routed by Host header.
  - Caddy's simpler model dominates this option at this footprint.

### Option D — Apple-bundled httpd

macOS ships Apache `httpd` in `/usr/sbin/`.

- **Pros:**
  - Zero install.
- **Cons:**
  - It's Apache, not nginx — Apple does not ship nginx despite ADR-0010 mentioning "Apple's built-in nginx fork." (Correcting that here: there is no bundled nginx.)
  - No built-in ACME; same ACME-client supervision cost as nginx, with less HTTPS-era ergonomics than either nginx or Caddy.
  - Tied to the OS-level binary, which Apple updates on its own schedule and which has historically lagged upstream Apache. Not seriously considered.

## Decision

**Option A — Caddy v2 on `mac-mini-2`.**

### Build and supervision

- **Binary:** Caddy v2 with the `caddy-dns/cloudflare` module compiled in. Either `xcaddy build` from source or pull from a known-good distribution that bundles the module. Vanilla `brew install caddy` is **not sufficient** — it ships without DNS provider modules.
- **Supervision:** launchd, owned by `local-computer-control`, matching the SvelteKit and Phoenix pattern from [ADR-0010](0010-web-frontend-hosting.md) and [ADR-0009](0009-worker-fleet-topology.md).
- **Caddyfile source:** lives in `distributed-ai`. `local-computer-control` provisions the path and reload mechanism.

### TLS and ACME

- **Issuance:** DNS-01 ACME against the Cloudflare-hosted `dinkerwupp.com` zone for both `i.dinkerwupp.com` and `dev.dinkerwupp.com`. Renewals automatic.
- **Cloudflare token:** a **separate, scoped Cloudflare API token** is provisioned for Caddy. Scope: `Zone:DNS:Edit` and `Zone:Zone:Read`, restricted to the `dinkerwupp.com` zone only. The broader-scoped token already present in `distributed-ai/.env` (used for one-shot DNS administration) is **never** reused for the Caddy runtime. Token provisioning is owned by `local-computer-control` and lands in an env var consumed by the launchd plist, not in `distributed-ai/.env`.
- **TLS policy:** Caddy defaults for protocol and cipher suite selection (TLS 1.2+, modern suites). **HSTS is not on by default in Caddy** and is added here as an explicit Caddyfile directive on both hostname blocks:

  ```caddyfile
  header Strict-Transport-Security "max-age=31536000; includeSubDomains"
  ```

  HSTS preload is intentionally **not** set in Phase 0 (the `preload` directive is omitted): preload is a one-way commitment to the browser HSTS preload list (removal takes weeks of propagation) and only makes sense once public ingress closes. Harder TLS policy (HSTS preload, key pinning, public ingress) remains deferred per ADR-0010.

### Routing

- **Host-header routing.** `i.dinkerwupp.com /` → SvelteKit prod on `127.0.0.1:3000`. `dev.dinkerwupp.com /` → SvelteKit dev on `127.0.0.1:3001`. `/api/*` and `/socket` on both hosts → Phoenix on `127.0.0.1:4000` (single shared Phoenix process today — per-environment Phoenix split is gated on ADR-0010's deferred dev/prod data isolation decision). The full bind table lives in [`03-operations/deployment.md`](../03-operations/deployment.md#current-web-frontend-host) and is the source of truth for the Caddyfile and for the SvelteKit launchd plists' `HOST=127.0.0.1` + `PORT=<num>` env vars (both required — `adapter-node` defaults `HOST` to `0.0.0.0` and would bind the LAN interface in violation of ADR-0010's loopback rule if `HOST` were omitted). Phoenix binds via `config/runtime.exs`, not env vars.
- **Path ownership** per ADR-0010 is honored at the proxy: `/api/*` and `/socket` proxy to Phoenix on the same host (different port); page routes proxy to SvelteKit SSR. `/health` maps to the internal SvelteKit `/_health` route.
- **WebSocket upgrade** enabled on `/socket`. Caddy's `reverse_proxy` directive handles HTTP/1.1 upgrades automatically.

### Listening surface

- **Caddy is name-bound, not catch-all.** Site blocks exist only for `i.dinkerwupp.com` and `dev.dinkerwupp.com`. Requests for any other host — `192.168.1.173`, `mac-mini-2.local`, an empty/missing host, or any other name — are **not routed to any upstream** and are not redirected. The exact failure surface depends on the scheme: HTTP requests reach Caddy's HTTP listener and are refused at the application layer (Caddy responds with a 421/404 or closes the connection, per its default empty-site behavior); HTTPS requests to those names typically fail at the TLS handshake before any HTTP status is produced, because Caddy has no certificate matching the requested SNI. Either way, no proxied response is served. This matters because a catch-all `:80 → :443` redirect on those non-DNS-01-eligible names would land the browser on an `https://` URL Caddy has no valid cert for; we'd swap a clear "not routed" outcome for a TLS error and a worse user experience.
- `:80` accepts requests for the two registered hostnames and redirects them to `:443`. ACME HTTP-01 challenges are not used (DNS-01 only); `:80` exists solely for the http→https redirect.
- `:443` is the only application listener. Binds to the LAN interface only.
- **The temporary local origins listed in [ADR-0010:105](0010-web-frontend-hosting.md) — `http://192.168.1.173`, `http://mac-mini-2.local` — were Phoenix `check_origin` allowlist entries for the pre-HTTPS spike phase, not browser entry points to Caddy.** They are obsolete now that DNS-01 ACME is wired up and Caddy is the front door; ADR-0010's `check_origin` allowlist should drop them when Phoenix's prod config is finalized. They are not exposed through Caddy.
- No public ingress in Phase 0 — the only thing on the public internet pointing at `mac-mini-2` is the DNS A-record, which resolves to a private RFC1918 address and is not reachable from outside the LAN.

## Consequences

- [`05-decisions/0010-web-frontend-hosting.md`](0010-web-frontend-hosting.md) status line drops "reverse-proxy software" from the deferred list. Session/cookie mechanism and dev/prod data isolation remain deferred. ADR-0010's deferred-items subsection gets a line noting reverse-proxy is closed by this ADR. The brief mention of "Apple's built-in nginx fork" is left as-is in ADR-0010's original prose — this ADR corrects the misconception in Option D above.
- [`03-operations/deployment.md`](../03-operations/deployment.md) "Current Web Frontend Host" updates: "The reverse-proxy software is deferred (Caddy / nginx / Traefik)…" becomes "Caddy v2 with the `caddy-dns/cloudflare` module, supervised by launchd." A concrete upstream bind table is added (SvelteKit prod `127.0.0.1:3000`, SvelteKit dev `127.0.0.1:3001`, Phoenix `127.0.0.1:4000` — single shared Phoenix process today, per-environment split gated on ADR-0010's deferred dev/prod data isolation decision), with explicit `HOST=127.0.0.1` + `PORT=<num>` env-var contract for the SvelteKit plists and a note that Phoenix binds via `config/runtime.exs` rather than env vars. `local-computer-control` provisioning gains: install Caddy with the cloudflare DNS module on `mac-mini-2`; provision a scoped Cloudflare API token for Caddy (separate from the existing one in `.env`); install the launchd plists with the documented `HOST` and `PORT` values. The "Deferred" bullet at the bottom drops reverse-proxy.
- [`04-roadmap/open-questions.md`](../04-roadmap/open-questions.md) deletes the standalone "Reverse-proxy software" pre-ADR item; the ADR-0010 summary line trims "reverse-proxy software" from the listed deferrals; a new "Accepted" row is added for ADR-0011.
- [`docs/README.md`](../README.md) accepted-decisions table gains a new row for ADR-0011.
- `distributed-ai` owns the Caddyfile source and the contract that Phoenix and SvelteKit upstreams are reachable at the documented `127.0.0.1` ports. `local-computer-control` owns the Caddy binary build/install, the launchd plist, the scoped Cloudflare API token, and firewall rules limiting `:80`/`:443` to the LAN interface.
- The Pre-Phase 0 spike unblocks: the front door has a concrete implementation, DNS-01 ACME issuance has a known path, and the WebSocket-upgrade requirement is satisfied.
- Token blast radius stays tight: even though Caddy's runtime token can edit DNS records on `dinkerwupp.com`, it cannot touch other zones, account-level settings, or the registrar. If the `mac-mini-2` host is compromised, the attacker's reachable Cloudflare surface is limited to the records inside one zone.

## References

- [ADR-0010](0010-web-frontend-hosting.md) — web frontend hosting; this ADR closes its reverse-proxy software deferral. Other deferred items in ADR-0010 (session/cookie mechanism, dev/prod data isolation, CSP, public ingress / mTLS / harder TLS) remain open.
- [ADR-0009](0009-worker-fleet-topology.md) — three-host worker fleet; Caddy does not sit in the Brain↔worker path. The Studio bearer-token auth model is unchanged.
- [ADR-0004](0004-realtime-transport.md) — Phoenix Channels over WebSocket; the proxy's WebSocket upgrade support honors this.
- [01-architecture/api-and-transport.md](../01-architecture/api-and-transport.md) — route ownership unchanged; this ADR specifies how the canonical origin enforces it.
- [03-operations/deployment.md](../03-operations/deployment.md) — Current Web Frontend Host section updated by this decision.
- [04-roadmap/open-questions.md](../04-roadmap/open-questions.md) — reverse-proxy item removed by this decision.
- Caddy documentation, `caddy-dns/cloudflare` module — DNS-01 provider for Cloudflare.
